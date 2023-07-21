#!/bin/bash
#set -e

# Auto restart services during apt rather than prompt for restart (new in Ubuntu 22)
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# Install all the needed packages
sudo apt-get update 

# sudo apt install xrdp lxde make gcc g++ libcairo2-dev libjpeg-turbo8-dev libtool-bin libossp-uuid-dev libavcodec-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libvorbis-dev libwebp-dev tomcat9 tomcat9-admin tomcat9-user nginx -y #firefox -y

sudo apt install xrdp lxde -y
apt-get install make gcc g++ libcairo2-dev libjpeg-turbo8-dev libtool-bin libossp-uuid-dev libavcodec-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libvorbis-dev libwebp-dev tomcat9 tomcat9-admin tomcat9-user nginx -y

#sudo apt install xrdp xfce4 xfce4-terminal make gcc g++ libcairo2-dev libjpeg-turbo8-dev libtool-bin libossp-uuid-dev libavcodec-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libvorbis-dev libwebp-dev tomcat9 tomcat9-admin tomcat9-user nginx firefox -y


# Install Visual Studio Code ??
# sudo apt install gnupg2 software-properties-common apt-transport-https wget -y
# wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
# sudo add-apt-repository -y "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
# sudo apt update
# sudo apt install code -y

# ## Install Terraform
# sudo apt-get install unzip -y
# wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
# echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# sudo apt update && sudo apt install terraform

# Start and enable Tomcat
sudo systemctl start tomcat9
sudo systemctl enable tomcat9

# Download and install Guacamole Server
wget https://downloads.apache.org/guacamole/1.5.2/source/guacamole-server-1.5.2.tar.gz -P /tmp/
tar xzf /tmp/guacamole-server-1.5.2.tar.gz -C /tmp/

(
    cd /tmp/guacamole-server-1.5.2
    sudo ./configure --with-init-dir=/etc/init.d
    sudo make
    sudo make install
    sudo ldconfig
)

sudo systemctl start guacd
sudo systemctl enable guacd 


####
sudo mkdir /etc/guacamole

echo "<user-mapping>
<authorize 
    username=\"${username}\"
    password=\"${password}\">
  <connection name=\"localhost-ssh\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">localhost</param>
    <param name=\"port\">22</param>
    <param name=\"username\">${username}</param>
    <param name=\"password\">${password}</param>
  </connection>    
  <connection name=\"localhost-rdp\">
    <protocol>rdp</protocol>
    <param name=\"hostname\">localhost</param>
    <param name=\"port\">3389</param>
    <param name=\"username\">${username}</param>
    <param name=\"password\">${password}</param>
  </connection>
  <connection name=\"spoke1-vm\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">${host1}</param>
    <param name=\"port\">22</param>
    <param name=\"username\">${username}</param>
    <param name=\"password\">${password}</param>
  </connection>  
  <connection name=\"spoke2-vm\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">${host2}</param>
    <param name=\"port\">22</param>
    <param name=\"username\">${username}</param>
    <param name=\"password\">${password}</param>
  </connection>
</authorize>
</user-mapping>" | sudo tee -a /etc/guacamole/user-mapping.xml


sudo wget https://downloads.apache.org/guacamole/1.5.2/binary/guacamole-1.5.2.war -O /etc/guacamole/guacamole.war 


sudo ln -s /etc/guacamole/guacamole.war /var/lib/tomcat9/webapps/ 
sleep 10 
sudo mkdir /etc/guacamole/{extensions,lib} 
sudo bash -c 'echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9'

echo "guacd-hostname: localhost
guacd-port:    4822
user-mapping:    /etc/guacamole/user-mapping.xml
auth-provider:    net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider"  | sudo tee -a /etc/guacamole/guacamole.properties

sudo ln -s /etc/guacamole /usr/share/tomcat9/.guacamole

sudo systemctl restart tomcat9 
sudo systemctl restart guacd 

#####
# Create user for RDP session
sudo useradd -m -s /bin/bash ${username} 
echo "${username}:${password}" | sudo chpasswd

# Create Desktop shortcuts
sudo mkdir /home/${username}/Desktop

echo "[Desktop Entry]
Type=Link
Name=Firefox Web Browser
Icon=firefox
URL=/usr/share/applications/firefox.desktop" | sudo tee -a /home/${username}/Desktop/firefox.desktop

echo "[Desktop Entry]
Type=Link
Name=LXTerminal
Icon=lxterminal
URL=/usr/share/applications/lxterminal.desktop" | sudo tee -a /home/${username}/Desktop/lxterminal.desktop

sudo chown ${username}:${username} /home/${username}/Desktop 
sudo chown ${username}:${username} /home/${username}/Desktop/*

# Nginx config - SSL redirect
echo "server {
    listen 80;
	  server_name ${public_ip};
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    access_log  /var/log/nginx/guac_access.log;
    error_log  /var/log/nginx/guac_error.log;

    location / {
          proxy_pass http://localhost:8080/guacamole/;
          proxy_buffering off;
          proxy_http_version 1.1;
          proxy_cookie_path /guacamole/ /;
    }
}" | sudo tee -a /etc/nginx/conf.d/default.conf

sudo chown demo:demo /home/demo/Desktop 
sudo chown demo:demo /home/demo/Desktop/* 


sudo chmod +x /home/demo/Desktop/*.desktop


# Fix authentication request when logging in via RDP

# echo "[Allow Colord all Users]
# Identity=unix-user:*
# Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
# ResultAny=no
# ResultInactive=no
# ResultActive=yes" | sudo tee -a /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla

# Nginx config - SSL redirect

sudo systemctl start nginx 
sudo systemctl enable nginx 
sudo systemctl restart nginx 

# Customize Guacamole login page
sudo ls -l /var/lib/tomcat9/webapps/guacamole/ 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-144.png 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-64.png 
# while [ ! -d /var/lib/tomcat9/webapps/guacamole/images/ ]; do
#   sleep 1
# done
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/ 
sudo cp logo-64.png /var/lib/tomcat9/webapps/guacamole/images/ 
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/guac-tricolor.png 
sudo sed -i "s/Apache Guacamole/Aviatrix/g" /var/lib/tomcat9/webapps/guacamole/translations/en.json 
sudo systemctl restart tomcat9 
sudo systemctl restart guacd 

##### Customize Linux Desktop
sudo cp logo-64.png /usr/share/lxde/images/lxde-icon.png 

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart