#!/usr/bin/env bash

SSH_PORT=2222
PASSWD_ROOT="rootpassword"

# Space-separated list of admin users
# Example: ADMIN_USERS="adminuser1 adminuser2"
ADMIN_USERS="adminuser1"

# For admin users, you can set a single password for all of them:
PASSWD_ADMIN="adminpassword"

AUTH_KEYS_FILE="ssh_authorized_keys"

