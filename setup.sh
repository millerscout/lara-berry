#!/bin/bash

# Lara-Berry Setup Script
# Installs Podman and Webmin on Raspberry Pi 4 with Raspberry Pi OS

set -e  # Exit on any error

echo "Starting Lara-Berry setup..."

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Podman
if command -v podman >/dev/null 2>&1; then
    echo "Podman is already installed."
else
    echo "Installing Podman..."
    sudo apt install -y podman
fi

# Configure rootless Podman for the current user
echo "Configuring rootless Podman..."
sudo usermod -aG podman $USER
sudo mkdir -p /etc/containers
sudo tee /etc/containers/registries.conf > /dev/null <<EOF
[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io']
EOF

# Install Webmin
if dpkg -l webmin 2>/dev/null | grep -q ^ii; then
    echo "Webmin is already installed."
else
    echo "Installing Webmin..."
    wget -qO - http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
    sudo sh -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list'
    sudo apt update
    sudo apt install -y webmin
fi

# Install Git
if command -v git >/dev/null 2>&1; then
    echo "Git is already installed."
else
    echo "Installing Git..."
    sudo apt install -y git
fi

# Install Python and pip for podman-compose
echo "Installing Python and pip..."
sudo apt install -y python3 python3-pip

# Install podman-compose
echo "Installing podman-compose..."
sudo pip3 install podman-compose

# Enable and start Webmin service
sudo systemctl enable webmin
sudo systemctl start webmin

# Install No-IP Dynamic Update Client
echo "Installing No-IP DUC..."
wget -q https://www.noip.com/client/linux/noip-duc-linux.tar.gz
tar xzf noip-duc-linux.tar.gz
cd noip-*
sudo make
sudo make install
cd ..
rm -rf noip-*

echo "No-IP installed. Run 'sudo noip2 -C' to configure with your No-IP account."

echo "Setup complete!"
echo "Podman installed and configured for rootless use."
echo "Webmin installed and running on https://your-pi-ip:10000"
echo "Reboot recommended: sudo reboot"