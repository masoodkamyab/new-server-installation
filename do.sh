#! /usr/bin/env bash

# Update and upgrade system packages
read -p "Do you want to run apt update and upgrade? [N/y] "
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo apt update && sudo apt upgrade -y
fi

# Install Vim and set as default editor
read -p "Do you want to install Vim and set it as the default editor? [N/y] "
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo apt install -y vim
  echo 'export EDITOR=/usr/bin/vim' | sudo tee /etc/profile.d/editor.sh > /dev/null
fi

# Set VI editing mode in inputrc
read -p "Do you want to update the .inputrc to enable VI editing mode? [N/y] "
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo 'set editing-mode vi' > "${HOME}/.inputrc"
fi

# Configure firewall
read -p "Do you want to configure the firewall? [N/y] "
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Configuring firewall..."
  sudo apt install -y ufw
  # Allow essential ports
  sudo ufw allow 22/tcp  # SSH
  sudo ufw allow 80/tcp  # HTTP
  sudo ufw allow 443/tcp # HTTPS

  # Allow custom ports
  read -p "Enter TCP ports to allow (space-separated): " tcp_ports
  for port in $tcp_ports; do
    sudo ufw allow ${port}/tcp
  done

  read -p "Enter UDP ports to allow (space-separated): " udp_ports
  for port in $udp_ports; do
    sudo ufw allow ${port}/udp
  done

  # Deny all other ports
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # Enable firewall
  sudo ufw enable
fi

# Confirm script completion
echo "Server initialization script completed successfully."

