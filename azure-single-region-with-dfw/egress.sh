#!/bin/bash

sudo hostnamectl set-hostname ${hostname}

# Create user for SSH session
sudo useradd -m -s /bin/bash ${username} 
echo "${username}:${password}" | sudo chpasswd 
sudo adduser ${username} sudo

sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config.d/50-cloud-init.conf
sudo /etc/init.d/ssh restart
