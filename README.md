# Server Initialization Script

This project contains a Bash script to initialize a new server with essential configurations and tools. The script is interactive and allows you to choose which tasks to perform.

## Features

- Updates and upgrades system packages
- Installs Vim and sets it as the default editor
- Enables VI editing mode in `.inputrc`
- Configures the firewall to allow specific TCP/UDP ports and denies others

## Prerequisites

- A Debian-based Linux distribution (e.g., Ubuntu)
- User with `sudo` privileges

## Usage

1. Clone this repository or copy the script to your local machine.
2. Make the script executable:
   ```bash
   chmod +x server_init_script.sh
   ```
3. Run the script:
   ```bash
   ./server_init_script.sh
   ```

## Script Workflow

1. **Update and Upgrade Packages**
   - Prompts the user to update and upgrade system packages using `apt`.
2. **Install Vim**
   - Installs Vim if not already installed.
   - Sets Vim as the default system editor by updating `/etc/profile.d/editor.sh`.
3. **Enable VI Editing Mode**
   - Updates the `.inputrc` file to enable VI editing mode.
4. **Configure Firewall**
   - Installs UFW if not already installed.
   - Allows essential ports for SSH, HTTP, and HTTPS.
   - Prompts the user to specify additional TCP and UDP ports to allow.
   - Denies all other ports and enables the firewall.

## Example Configuration

During the script execution, you will be prompted to perform tasks. For example:

- **Update and Upgrade Packages**:
  ```
  Do you want to run apt update and upgrade? [N/y]
  ```
- **Allow Custom TCP/UDP Ports**:
  ```
  Enter TCP ports to allow (space-separated): 8080 3306
  Enter UDP ports to allow (space-separated): 1194
  ```

