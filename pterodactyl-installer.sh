#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
#                                                                                    #
# Copyright (C) 2018 - 2025, Vilhelm Prytz, <vilhelm@prytznet.se>                    #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/pterodactyl-installer/pterodactyl-installer/blob/master/LICENSE #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
#                                                                                    #
######################################################################################

# Prompt for password before proceeding
echo -n "Enter password to continue: "
read -s PASSWORD
echo

# Check if password is correct (password is 'aryastore')
if [[ "$PASSWORD" != "aryastore" ]]; then
  echo "Incorrect password. Exiting."
  exit 1
fi

# Environment variables
export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"
LOG_PATH="/var/log/pterodactyl-installer.log"

# Check for curl
if ! command -v curl &>/dev/null; then
  echo "* curl is required for this script."
  echo "* Install it using apt (Debian-based) or yum/dnf (CentOS-based)."
  exit 1
fi

# Always remove lib.sh before downloading
[ -f /tmp/lib.sh ] && rm -f /tmp/lib.sh
curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
# shellcheck source=lib/lib.sh
source /tmp/lib.sh

# Execute installation
execute() {
  echo -e "\n\n* pterodactyl-installer $(date)\n\n" >>"$LOG_PATH"

  [[ "$1" == *"canary"* ]] && GITHUB_SOURCE="master" && SCRIPT_RELEASE="canary"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a "$LOG_PATH"

  if [[ -n $2 ]]; then
    echo -e -n "* Installation of $1 completed. Do you want to proceed with $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      error "Installation of $2 aborted."
      exit 1
    fi
  fi
}

# Configure Wings using token and start service
configure_wings() {
  echo "Configuring Wings..."

  # Prompt user for necessary configuration settings
  echo -n "Enter the panel URL (e.g., https://your-panel-url): "
  read -r PANEL_URL
  echo -n "Enter the token for Wings: "
  read -r TOKEN
  echo -n "Enter the node domain (e.g., node1.example.com): "
  read -r NODE_DOMAIN

  # Run Wings configuration with the provided details
  echo "Running: cd /etc/pterodactyl && sudo wings configure --panel-url $PANEL_URL --token $TOKEN --node $NODE_DOMAIN"
  cd /etc/pterodactyl && sudo wings configure --panel-url "$PANEL_URL" --token "$TOKEN" --node "$NODE_DOMAIN"

  # Start and enable the Wings service using systemctl
  echo "Starting Wings service..."
  sudo systemctl start wings
  sudo systemctl enable wings
  echo "Wings service started and enabled."

  echo "Wings configuration completed and service is running."
}

# Display welcome message
welcome ""

# Main menu loop
done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine (wings script runs after panel)"
    "Install panel with canary version of the script"
    "Install Wings with canary version of the script"
    "Install both [3] and [4] on the same machine (wings script runs after panel)"
    "Uninstall panel or wings with canary version of the script"
    "Configure Wings"  # New option for configuring Wings
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
    "configure_wings"  # Action for configuring Wings
  )

  output "What would you like to do?"

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]} - 1)): "
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i++)); do echo "$i"; done)")
  if [[ ! " ${valid_input[*]} " =~ ${action} ]]; then
    error "Invalid option"
  else
    done=true
    IFS=";" read -r i1 i2 <<<"${actions[$action]}"
    execute "$i1" "$i2"
  fi
done

# Clean up
rm -f /tmp/lib.sh
