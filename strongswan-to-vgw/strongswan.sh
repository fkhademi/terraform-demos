#!/bin/bash

sudo apt update
sudo apt install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins frr strongswan-swanctl -y
ipsec rereadsecrets
ipsec reload
ipsec restart


echo ": PSK ${psk}" | sudo tee -a /etc/ipsec.secrets

##
# create strongswan config
output_script() {
    cat << 'EOM'

# ipsec.conf - strongSwan IPsec configuration file

config setup
    charondebug="cfg 2, chd 2, esp 2, ike 2, knl 2, lib 2, net 2, tls 2"
    uniqueids = yes

conn %default
    ikelifetime=8h
    rekey=yes
    reauth=no
    keyexchange=ikev2
    authby=secret
    dpdaction=restart
    closeaction=restart

conn vgw1
    mark=0x2
    auto=start
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=no
    leftauth=psk
    rightauth=psk
    forceencaps=yes
    ike=aes256-sha256-modp2048
    esp=aes256-sha256-modp2048
    dpdaction=restart
    dpddelay=10s
    dpdtimeout=30s
    rekey=yes
    left=--LOCAL_IP--
    leftid=${local_public_ip}
    leftsubnet=0.0.0.0/0
    right=${remote_public_ip}
    rightid=${remote_public_ip}
    rightsubnet=0.0.0.0/0
    leftupdown=/usr/local/sbin/ipsec-notify1.sh
    aggressive=no

conn vgw2
    mark=0x3
    auto=start
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=no
    leftauth=psk
    rightauth=psk
    forceencaps=yes
    ike=aes256-sha256-modp2048
    esp=aes256-sha256-modp2048
    dpdaction=restart
    dpddelay=10s
    dpdtimeout=30s
    rekey=yes
    left=--LOCAL_IP--
    leftid=${local_public_ip}
    leftsubnet=0.0.0.0/0
    right=${remote_public_ip2}
    rightid=${remote_public_ip2}
    rightsubnet=0.0.0.0/0
    leftupdown=/usr/local/sbin/ipsec-notify2.sh
    aggressive=no

EOM
}

output_script > /etc/ipsec.conf

# search and replace some values in the ipsec config
LOCAL_INTERFACE_NAME=$(ip route get 8.8.8.8 | awk '{printf $5}')
LOCAL_IP=$(/sbin/ip -o -4 addr list $LOCAL_INTERFACE_NAME | awk '{print $4}' | cut -d/ -f1)

sudo sed -i "s/--LOCAL_IP--/$LOCAL_IP/g" /etc/ipsec.conf

# get and build ipsec tunnel interface configs
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/ipsec-notify.sh -P /usr/local/sbin/

sudo cp /usr/local/sbin/ipsec-notify.sh /usr/local/sbin/ipsec-notify1.sh
sudo cp /usr/local/sbin/ipsec-notify.sh /usr/local/sbin/ipsec-notify2.sh

LOCAL_INTERFACE_NAME=$(ip route get 8.8.8.8 | awk '{printf $5}')
LOCAL_IP=$(/sbin/ip -o -4 addr list $LOCAL_INTERFACE_NAME | awk '{print $4}' | cut -d/ -f1)

sudo sed -i "s/--LOCAL_IP--/${local_tunnel1_interface}/g" /usr/local/sbin/ipsec-notify1.sh
sudo sed -i "s/--LOCAL_INTERFACE--/$LOCAL_INTERFACE_NAME/g" /usr/local/sbin/ipsec-notify1.sh

sudo sed -i "s/--LOCAL_IP--/${local_tunnel2_interface}/g" /usr/local/sbin/ipsec-notify2.sh
sudo sed -i "s/--LOCAL_INTERFACE--/$LOCAL_INTERFACE_NAME/g" /usr/local/sbin/ipsec-notify2.sh


chmod +x /usr/local/sbin/ipsec-notify1.sh
chmod +x /usr/local/sbin/ipsec-notify2.sh
###

# Set flags for strongswan
sudo sed -i "s/# install_routes = yes/install_routes = no/g" /etc/strongswan.d/charon.conf
sudo sed -i "s/# install_virtual_ip = yes/install_virtual_ip = no/g" /etc/strongswan.d/charon.conf

sudo ipsec rereadsecrets
sudo ipsec reload
sudo ipsec restart

# Enable BGP
sudo sed -i "s/bgpd=no/bgpd=yes/g" /etc/frr/daemons

# Create FRR config
sudo tee /etc/frr/frr.conf > /dev/null <<EOT
hostname gw
password zebra

ip route ${local_prefix} Null0

router bgp ${local_asn}
    no bgp ebgp-requires-policy
    neighbor ${remote_tunnel1_interface} remote-as ${remote_asn}
    neighbor ${remote_tunnel2_interface} remote-as ${remote_asn}
    address-family ipv4 unicast
        network ${local_prefix}

log stdout
EOT

sudo service frr restart

# Enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.$LOCAL_INTERFACE_NAME.disable_policy=1
sudo sysctl -w net.ipv4.conf.lo.disable_policy=1

sudo sysctl -w net.ipv4.conf.$LOCAL_INTERFACE_NAME.disable_xfrm=1 # Disable encryption on interface