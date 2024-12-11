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
2. Run the script:
   ```bash
   ./server_init_script.sh
   ```

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

