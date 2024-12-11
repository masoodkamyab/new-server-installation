#!/usr/bin/env bash


set -euo pipefail


# Load variables if vars.sh exists
if [ -f vars.sh ]; then
  source ./vars.sh
fi


# If a variable is not defined, prompt the user or set a default.
# SSH_PORT fallback
if [ -z "${SSH_PORT:-}" ]; then
  read -p "Enter SSH port [default: 1111]: " input_ssh_port
  SSH_PORT="${input_ssh_port:-1111}"
fi


# PASSWD_ROOT fallback
if [ -z "${PASSWD_ROOT:-}" ]; then
  read -sp "Enter root password: " PASSWD_ROOT
  echo
fi


# ADMIN_USERS fallback (space-separated)
if [ -z "${ADMIN_USERS:-}" ]; then
  read -p "Enter admin usernames (space-separated): " ADMIN_USERS
fi


if [ -z "${ADMIN_USERS}" ]; then
  echo "No admin users provided. Exiting."
  exit 1
fi


# If PASSWD_ADMIN not provided, prompt for each admin user's password individually
admin_users_passwords=()
if [ -z "${PASSWD_ADMIN:-}" ]; then
  echo "No PASSWD_ADMIN set. You will be prompted for each admin user's password."
  for user in $ADMIN_USERS; do
    read -sp "Enter password for ${user}: " user_pass
    echo
    admin_users_passwords+=("${user}:${user_pass}")
  done
else
  # Use the same password for all admin users
  for user in $ADMIN_USERS; do
    admin_users_passwords+=("${user}:${PASSWD_ADMIN}")
  done
fi


echo "Starting system preparation..."
apt update
apt -y dist-upgrade
apt -y purge ufw
apt -y install iptables-persistent vim


# Set vim as default editor if not already set
if [ ! -f /etc/profile.d/editor.sh ] || ! grep -q "EDITOR=" /etc/profile.d/editor.sh; then
  echo 'export EDITOR=/usr/bin/vim' | sudo tee /etc/profile.d/editor.sh > /dev/null
fi


# Update .inputrc without overwriting existing content
if [ ! -f "${HOME}/.inputrc" ]; then
  echo "set editing-mode vi" > "${HOME}/.inputrc"
else
  if ! grep -q "set editing-mode vi" "${HOME}/.inputrc"; then
    echo "set editing-mode vi" >> "${HOME}/.inputrc"
  fi
fi


# Helper function to set authorized keys for a given user
set_authorized_keys_for_user() {
  local username="$1"
  local home_dir
  if [ "$username" = "root" ]; then
    home_dir="/root"
  else
    home_dir="/home/${username}"
  fi

  # Look for user-specific authorized keys file
  user_specific_keys="ssh_authorized_keys_${username}"
  global_keys="ssh_authorized_keys"

  mkdir -p "${home_dir}/.ssh"
  if [ -f "${user_specific_keys}" ]; then
    # Use user-specific file if exists
    cp "${user_specific_keys}" "${home_dir}/.ssh/authorized_keys"
  elif [ -f "${global_keys}" ]; then
    # Fall back to global keys file
    cp "${global_keys}" "${home_dir}/.ssh/authorized_keys"
  else
    # No keys found, create an empty authorized_keys
    echo "Warning: No authorized keys file found for ${username}."
    touch "${home_dir}/.ssh/authorized_keys"
  fi

  chown -R ${username}:${username} "${home_dir}/.ssh"
  chmod 700 "${home_dir}/.ssh"
  chmod 600 "${home_dir}/.ssh/authorized_keys"
}


# Add administrator users and configure them
for user in $ADMIN_USERS; do
  if ! id -u "$user" >/dev/null 2>&1; then
    echo "Adding administrator user: ${user}"
    adduser --disabled-password --gecos "" "${user}"
    adduser "${user}" sudo
  else
    echo "User ${user} already exists, skipping creation."
  fi

  echo "Adding SSH authorized key(s) for user ${user}"
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

  # Add sudoers entry if it doesn't exist
  if [ ! -f "/etc/sudoers.d/${user}" ]; then
    echo "Updating sudoers.d/${user}"
    echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${user}
    chmod 0440 /etc/sudoers.d/${user}
  fi
done


# Handle root authorized keys separately
echo "Adding SSH authorized key(s) for user root"
set_authorized_keys_for_user "root"


# Set passwords for root and admin users
echo "Changing passwords..."
{
  echo "root:${PASSWD_ROOT}"
  for entry in "${admin_users_passwords[@]}"; do
    echo "${entry}"
  done
} | chpasswd


# Update SSH settings
sed -i '/^#\?Port/d' /etc/ssh/sshd_config
sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '/ubuntuserver-dofirst/d' /etc/ssh/sshd_config
echo "" >> /etc/ssh/sshd_config
echo "# Added by do.sh" >> /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config


# Configure iptables firewall
echo "Configuring iptables firewall..."


# Iptables
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT
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


# Restart SSH to apply changes
systemctl restart sshd


echo "Server initialization completed successfully."

