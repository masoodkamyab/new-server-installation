#!/usr/bin/env bash


set -euo pipefail


#####################################
# Load Variables (if any)
#####################################

if [ -f vars.sh ]; then
  . ./vars.sh
fi


#####################################
# Determine SSH_PORT
#####################################

if [ -z "${SSH_PORT:-}" ]; then
  echo
  echo "Enter SSH port [press Enter for default: 1111]:"
  read input_ssh_port
  if [ -z "${input_ssh_port}" ]; then
    SSH_PORT="1111"
  else
    SSH_PORT="${input_ssh_port}"
  fi
fi


#####################################
# Determine PASSWD_ROOT
#####################################

if [ -z "${PASSWD_ROOT:-}" ]; then
  echo
  echo "Enter root password [press Enter for default: rootpassword]:"
  read -sp "" input_root_pass
  echo
  if [ -z "${input_root_pass}" ]; then
    PASSWD_ROOT="rootpassword"
  else
    PASSWD_ROOT="${input_root_pass}"
  fi
fi


#####################################
# Determine ADMIN_USERS
#####################################

if [ -z "${ADMIN_USERS:-}" ]; then
  echo
  echo "Enter admin usernames (space-separated) [press Enter for default: adminuser]:"
  read input_admin_users
  if [ -z "${input_admin_users}" ]; then
    ADMIN_USERS="adminuser"
  else
    ADMIN_USERS="${input_admin_users}"
  fi
fi


#####################################
# Determine PASSWD_ADMIN or prompt individually
#####################################

admin_users_passwords=()

if [ -z "${PASSWD_ADMIN:-}" ]; then
  echo
  echo "No PASSWD_ADMIN set. Prompting for each admin user's password."
  for usr in ${ADMIN_USERS}; do
    echo
    echo "Enter password for ${usr} [press Enter for default: adminpassword]:"
    read -sp "" input_admin_pass
    echo
    if [ -z "${input_admin_pass}" ]; then
      input_admin_pass="adminpassword"
    fi
    admin_users_passwords+=("${usr}:${input_admin_pass}")
  done
else
  for usr in ${ADMIN_USERS}; do
    admin_users_passwords+=("${usr}:${PASSWD_ADMIN}")
  done
fi


#####################################
# System Update & Setup
#####################################

echo
echo "Starting system preparation..."

apt update
apt -y dist-upgrade
apt -y purge ufw

export DEBIAN_FRONTEND=noninteractive

echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" > /tmp/ip4.conf
debconf-set-selections < /tmp/ip4.conf

echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" > /tmp/ip6.conf
debconf-set-selections < /tmp/ip6.conf

apt -y install iptables-persistent
apt -y install vim


#####################################
# Set Vim as Default Editor
#####################################

if [ ! -f /etc/profile.d/editor.sh ]; then
  echo 'export EDITOR=/usr/bin/vim' > /etc/profile.d/editor.sh
fi

if ! grep -q "EDITOR=" /etc/profile.d/editor.sh; then
  echo 'export EDITOR=/usr/bin/vim' >> /etc/profile.d/editor.sh
fi


#####################################
# Update .inputrc for root
#####################################

if [ ! -f "${HOME}/.inputrc" ]; then
  echo "set editing-mode vi" > "${HOME}/.inputrc"
else
  if ! grep -q "set editing-mode vi" "${HOME}/.inputrc"; then
    echo "set editing-mode vi" >> "${HOME}/.inputrc"
  fi
fi


#####################################
# Configure Admin Users and Their SSH Keys
#####################################

for usr in ${ADMIN_USERS}; do
  id -u "${usr}" >/dev/null 2>&1 || {
    echo
    echo "Adding administrator user: ${usr}"
    adduser --disabled-password --gecos "" "${usr}"
    adduser "${usr}" sudo
  }

  home_dir="/home/${usr}"
  if [ "${usr}" = "root" ]; then
    home_dir="/root"
  fi

  mkdir -p "${home_dir}/.ssh"

  if [ -f "ssh_authorized_keys_${usr}" ]; then
    cp "ssh_authorized_keys_${usr}" "${home_dir}/.ssh/authorized_keys"
  else
    if [ -f "ssh_authorized_keys" ]; then
      cp "ssh_authorized_keys" "${home_dir}/.ssh/authorized_keys"
    else
      touch "${home_dir}/.ssh/authorized_keys"
    fi
  fi

  chown -R ${usr}:${usr} "${home_dir}/.ssh"
  chmod 700 "${home_dir}/.ssh"
  chmod 600 "${home_dir}/.ssh/authorized_keys"

  user_inputrc="${home_dir}/.inputrc"
  if [ ! -f "${user_inputrc}" ]; then
    echo "set editing-mode vi" > "${user_inputrc}"
  else
    if ! grep -q "set editing-mode vi" "${user_inputrc}"; then
      echo "set editing-mode vi" >> "${user_inputrc}"
    fi
  fi

  chown ${usr}:${usr} "${user_inputrc}"

  if [ ! -f "/etc/sudoers.d/${usr}" ]; then
    echo "${usr} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${usr}"
    chmod 0440 "/etc/sudoers.d/${usr}"
  fi
done


#####################################
# Configure Root Authorized Keys
#####################################

root_home="/root"
mkdir -p "${root_home}/.ssh"

if [ -f "ssh_authorized_keys_root" ]; then
  cp "ssh_authorized_keys_root" "${root_home}/.ssh/authorized_keys"
else
  if [ -f "ssh_authorized_keys" ]; then
    cp "ssh_authorized_keys" "${root_home}/.ssh/authorized_keys"
  else
    touch "${root_home}/.ssh/authorized_keys"
  fi
fi

chown -R root:root "${root_home}/.ssh"
chmod 700 "${root_home}/.ssh"
chmod 600 "${root_home}/.ssh/authorized_keys"


#####################################
# Set Passwords
#####################################

echo
echo "Changing passwords..."
echo "root:${PASSWD_ROOT}" > /tmp/passwords.txt
for entry in "${admin_users_passwords[@]}"; do
  echo "${entry}" >> /tmp/passwords.txt
done
chpasswd < /tmp/passwords.txt


#####################################
# Update SSH Configuration
#####################################

sed -i '/^#\?Port/d' /etc/ssh/sshd_config
sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/ubuntuserver-afterinstall/d' /etc/ssh/sshd_config

echo "" >> /etc/ssh/sshd_config
echo "# Added by ubuntuserver-afterinstall/do.sh" >> /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config


#####################################
# Configure iptables Firewall
#####################################

echo
echo "Configuring iptables firewall..."

iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport "${SSH_PORT}" -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

echo
echo "Enter additional TCP ports to allow (space-separated) or leave empty:"
read input_tcp_ports
for port in ${input_tcp_ports}; do
  iptables -A INPUT -p tcp --dport "${port}" -j ACCEPT
done

echo
echo "Enter additional UDP ports to allow (space-separated) or leave empty:"
read input_udp_ports
for port in ${input_udp_ports}; do
  iptables -A INPUT -p udp --dport "${port}" -j ACCEPT
done

netfilter-persistent save


#####################################
# Restart SSH Service
#####################################

echo
echo "Restarting SSH service..."
systemctl restart sshd


#####################################
# Done
#####################################

echo
echo "Server initialization completed successfully."
echo
