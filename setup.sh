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
sudo groupadd -f podman
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
sudo pip3 install --break-system-packages podman-compose

# Create systemd service to start podman-compose on boot
echo "Creating systemd service for automatic startup..."
sudo tee /etc/systemd/system/lara-berry.service > /dev/null <<EOF
[Unit]
Description=Lara-Berry Podman Compose
After=network.target

[Service]
Type=oneshot
User=$USER
WorkingDirectory=/home/$USER/lara-berry
ExecStart=/usr/local/bin/podman-compose up -d
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable lara-berry

# Enable and start Webmin service
sudo systemctl enable webmin
sudo systemctl start webmin

# Install No-IP Dynamic Update Client
if command -v noip2 >/dev/null 2>&1; then
    echo "No-IP DUC is already installed."
else
    echo "Installing No-IP DUC..."
    wget -q https://www.noip.com/client/linux/noip-duc-linux.tar.gz
    tar xzf noip-duc-linux.tar.gz
    NOIP_DIR=$(ls -d noip-*/ | head -1)
    cd "$NOIP_DIR"
    sudo make
    sudo make install
    cd ..
    rm -rf noip-* noip-duc-linux.tar.gz
fi

echo "No-IP installed. Run 'sudo noip2 -C' to configure with your No-IP account."

echo "Setup complete!"
echo "Podman installed and configured for rootless use."
echo "Webmin installed and running on https://your-pi-ip:10000"
echo "Reboot recommended: sudo reboot"