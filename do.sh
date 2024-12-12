#!/usr/bin/env bash


set -euo pipefail


#####################################
# Load Variables
#####################################
if [ -f vars.sh ]; then
  source ./vars.sh
fi


#####################################
# Prompt Functions
#####################################
prompt_nonempty() {
  # Prompt the user until a non-empty input is provided.
  local var_name="$1"
  local prompt_message="$2"
  local input_value=""
  while [ -z "${input_value}" ]; do
    read -p "${prompt_message}: " input_value
    if [ -z "${input_value}" ]; then
      echo "Input cannot be empty. Please try again."
    fi
  done
  eval "${var_name}=\"${input_value}\""
}


prompt_password() {
  # Prompt for a password without echoing.
  local var_name="$1"
  local prompt_message="$2"
  local password=""
  read -sp "${prompt_message}: " password
  echo
  eval "${var_name}=\"${password}\""
}


#####################################
# Set or Prompt for Required Variables
#####################################
# SSH_PORT: default 1111 if not set
if [ -z "${SSH_PORT:-}" ]; then
  read -p "Enter SSH port [default: 1111]: " input_ssh_port
  SSH_PORT="${input_ssh_port:-1111}"
fi


# PASSWD_ROOT: prompt if not set
if [ -z "${PASSWD_ROOT:-}" ]; then
  prompt_password "PASSWD_ROOT" "Enter root password"
fi


# ADMIN_USERS: prompt until non-empty if not set
if [ -z "${ADMIN_USERS:-}" ]; then
  prompt_nonempty "ADMIN_USERS" "Enter admin usernames (space-separated)"
fi


# Determine admin users' passwords
admin_users_passwords=()
if [ -z "${PASSWD_ADMIN:-}" ]; then
  # Prompt individually for each admin user's password
  echo "No PASSWD_ADMIN set. You will be prompted for each admin user's password."
  for user in $ADMIN_USERS; do
    prompt_password "user_pass" "Enter password for ${user}"
    admin_users_passwords+=("${user}:${user_pass}")
  done
else
  # Use the same password for all admin users
  for user in $ADMIN_USERS; do
    admin_users_passwords+=("${user}:${PASSWD_ADMIN}")
  done
fi


#####################################
# System Update & Setup
#####################################
echo "Starting system preparation..."
apt update
apt -y dist-upgrade
apt -y purge ufw


# Pre-answer iptables-persistent prompts
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt -y install iptables-persistent vim


#####################################
# Set Vim as Default Editor
#####################################
if [ ! -f /etc/profile.d/editor.sh ] || ! grep -q "EDITOR=" /etc/profile.d/editor.sh; then
  echo 'export EDITOR=/usr/bin/vim' | tee /etc/profile.d/editor.sh > /dev/null
fi


#####################################
# Update .inputrc for root (no overwrite)
#####################################
if [ ! -f "${HOME}/.inputrc" ]; then
  echo "set editing-mode vi" > "${HOME}/.inputrc"
else
  if ! grep -q "set editing-mode vi" "${HOME}/.inputrc"; then
    echo "set editing-mode vi" >> "${HOME}/.inputrc"
  fi
fi


#####################################
# Function: Set Authorized Keys
#####################################
set_authorized_keys_for_user() {
  local username="$1"
  local home_dir

  if [ "${username}" = "root" ]; then
    home_dir="/root"
  else
    home_dir="/home/${username}"
  fi

  # Determine user-specific and global keys files
  local user_specific_keys="ssh_authorized_keys_${username}"
  local global_keys="ssh_authorized_keys"

  mkdir -p "${home_dir}/.ssh"
  if [ -f "${user_specific_keys}" ]; then
    cp "${user_specific_keys}" "${home_dir}/.ssh/authorized_keys"
  elif [ -f "${global_keys}" ]; then
    cp "${global_keys}" "${home_dir}/.ssh/authorized_keys"
  else
    echo "Warning: No authorized keys file found for ${username}."
    touch "${home_dir}/.ssh/authorized_keys"
  fi

  chown -R ${username}:${username} "${home_dir}/.ssh"
  chmod 700 "${home_dir}/.ssh"
  chmod 600 "${home_dir}/.ssh/authorized_keys"
}


#####################################
# Configure Admin Users
#####################################
for user in $ADMIN_USERS; do
  # Create the admin user if not exists
  if ! id -u "$user" >/dev/null 2>&1; then
    echo "Adding administrator user: ${user}"
    adduser --disabled-password --gecos "" "${user}"
    adduser "${user}" sudo
  else
    echo "User ${user} already exists, skipping creation."
  fi

  echo "Adding SSH authorized keys for ${user}"
  set_authorized_keys_for_user "${user}"

  # Update user-specific .inputrc without overwriting
  user_inputrc="/home/${user}/.inputrc"
  if [ ! -f "${user_inputrc}" ]; then
    echo "set editing-mode vi" > "${user_inputrc}"
  else
    if ! grep -q "set editing-mode vi" "${user_inputrc}"; then
      echo "set editing-mode vi" >> "${user_inputrc}"
    fi
  fi
  chown ${user}:${user} "${user_inputrc}"

  # Set sudoers entry if not already present
  if [ ! -f "/etc/sudoers.d/${user}" ]; then
    echo "${user} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${user}"
    chmod 0440 "/etc/sudoers.d/${user}"
  fi
done


#####################################
# Configure Root Authorized Keys
#####################################
echo "Adding SSH authorized keys for root"
set_authorized_keys_for_user "root"


#####################################
# Set Passwords
#####################################
echo "Changing passwords..."
{
  echo "root:${PASSWD_ROOT}"
  for entry in "${admin_users_passwords[@]}"; do
    echo "${entry}"
  done
} | chpasswd


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
echo "Configuring iptables firewall..."
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH on the specified port
iptables -A INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Prompt for additional ports
read -p "Enter additional TCP ports to allow (space-separated) or leave empty: " tcp_ports
for port in $tcp_ports; do
  iptables -A INPUT -p tcp --dport ${port} -j ACCEPT
done


read -p "Enter additional UDP ports to allow (space-separated) or leave empty: " udp_ports
for port in $udp_ports; do
  iptables -A INPUT -p udp --dport ${port} -j ACCEPT
done


# Save firewall rules
netfilter-persistent save


#####################################
# Restart SSH Service
#####################################
systemctl restart sshd


echo "Server initialization completed successfully."

