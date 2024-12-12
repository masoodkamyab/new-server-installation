# Server Preparation Script

## Features
- Secure server initialization using `iptables` firewall rules.
- Automatic setup of administrative users with optional password prompts.
- Flexible SSH configuration including custom ports and authorized keys.
- Automatic installation and configuration of `vim` as the default editor.
- Non-interactive installation of `iptables-persistent` for firewall persistence.
- Interactive prompts for any missing variables (e.g., SSH port, root password, admin users).

## Prerequisites
- A Debian or Ubuntu-based Linux server.
- `curl` installed if you want to run the script directly from a URL.
- `git` installed if you want to clone the repository.

## Usage

1. **One-line installation via curl**  
   ```bash
   curl -sL "https://raw.githubusercontent.com/agrinco/ubuntuserver-afterinstall/main/do.sh" | sudo bash
   ```
   This will run the script directly, prompting you for any missing variables.

2. **Using Git**  
   ```bash
   git clone https://github.com/agrinco/ubuntuserver-afterinstall.git
   cd ubuntuserver-afterinstall/
   # Update vars.sh with your desired configurations
   sudo ./do.sh
   ```

## Example Configuration

### vars.sh Example
```bash
#!/usr/bin/env bash

# Set a custom SSH port
SSH_PORT=2222

# Set a root password (otherwise the script will prompt)
PASSWD_ROOT="SuperSecureRootPassword"

# Provide a space-separated list of admin users
ADMIN_USERS="adminuser1 adminuser2"

# Optionally, set a single password for all admin users
PASSWD_ADMIN="CommonAdminPass"

# If you have global or user-specific authorized keys files, place them in the same directory:
# ssh_authorized_keys          -> global authorized keys for all users
# ssh_authorized_keys_root     -> authorized keys for root
# ssh_authorized_keys_adminuser1  -> authorized keys for adminuser1
```

### Interactive Prompts
If you run the script without pre-configuring vars.sh, you will be asked:
- **SSH Port**: If SSH_PORT is not set, you’ll be prompted to enter it.
- **Root Password**: If PASSWD_ROOT is not set, the script will ask for it securely.
- **Admin Users**: If ADMIN_USERS is not set, the script will prompt until you provide at least one user.
- If PASSWD_ADMIN is not set, it will prompt you individually for each admin user’s password.
```plaintext
Enter SSH port [default: 1111]: 2222
Enter root password: ******
Enter admin usernames (space-separated): adminuser1 adminuser2
No PASSWD_ADMIN set. You will be prompted for each admin user's password.
Enter password for adminuser1: ******
Enter password for adminuser2: ******
```
