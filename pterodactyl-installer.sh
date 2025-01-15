#!/bin/bash

set -e

######################################################################################
# Project 'pterodactyl-installer'                                                    #
# Copyright (C) 2018 - 2025, Vilhelm Prytz, <vilhelm@prytznet.se>                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
######################################################################################

# Function to display a welcome message
welcome_message() {
  local cyan="\033[36m"
  local yellow="\033[33m"
  local reset="\033[0m"
  echo -e "${cyan}\n\nWelcome to the installer Pterodactyl by ARYASTORE!${reset}"
  echo -e "${yellow}This script will guide you through the installation process.${reset}\n"
}

# Prompt for password before proceeding
prompt_password() {
  echo -n "Enter password to continue: "
  read -s PASSWORD
  echo

  # Check if password is correct (password is 'aryastore')
  if [[ "$PASSWORD" != "aryastore" ]]; then
    echo -e "\033[31mIncorrect password. Exiting.\033[0m"
    exit 1
  fi
}

# Install required libraries and dependencies
install_dependencies() {
  echo "Installing necessary libraries and dependencies..."
  sudo apt-get update
  sudo apt-get install -y \
    curl \
    wget \
    unzip \
    tar \
    gnupg \
    software-properties-common \
    git \
    build-essential \
    libssl-dev \
    ufw \
    fail2ban
  echo "Dependencies installation complete."
}

# Install and configure Fail2Ban
configure_fail2ban() {
  echo "Installing Fail2Ban..."
  sudo apt-get install -y fail2ban

  echo "Configuring Fail2Ban..."
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban

  # Customize Fail2Ban settings (basic configuration)
  echo "[DEFAULT]" | sudo tee -a /etc/fail2ban/jail.local
  echo "bantime = 3600" | sudo tee -a /etc/fail2ban/jail.local
  echo "findtime = 600" | sudo tee -a /etc/fail2ban/jail.local
  echo "maxretry = 3" | sudo tee -a /etc/fail2ban/jail.local
  echo "enabled = true" | sudo tee -a /etc/fail2ban/jail.local

  echo "Fail2Ban configuration complete."
}

# Setup UFW firewall rules to protect from DDoS
configure_ufw() {
  echo "Setting up UFW firewall..."

  # Allow basic services (SSH, HTTP, HTTPS)
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https

  # Enable rate-limiting for SSH to prevent brute-force attacks
  sudo ufw limit ssh

  # Set default policies to deny incoming traffic and allow outgoing
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # Enable UFW
  sudo ufw enable

  echo "UFW firewall configured."
}

# Configure TCP SYN Cookies to protect against SYN Flood attacks
configure_syn_cookies() {
  echo "Configuring TCP SYN Cookies..."

  # Enable SYN cookies
  sudo sysctl -w net.ipv4.tcp_syncookies=1
  echo "net.ipv4.tcp_syncookies=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p

  echo "SYN Cookies protection is enabled."
}

# Main menu loop
main_menu() {
  local done=false
  while [ "$done" == false ]; do
    options=(
      "Install the panel"
      "Install Wings"
      "Install both [0] and [1] on the same machine (wings script runs after panel)"
      "Configure Fail2Ban (Anti-DDoS)"
      "Configure UFW firewall (Anti-DDoS)"
      "Enable TCP SYN Cookies (Anti-DDoS)"
      "Install necessary dependencies"
    )

    actions=(
      "panel"
      "wings"
      "panel;wings"
      "configure_fail2ban"
      "configure_ufw"
      "configure_syn_cookies"
      "install_dependencies"
    )

    echo -e "\033[36mWhat would you like to do?\033[0m"
    for i in "${!options[@]}"; do
      echo -e "[${yellow}$i${reset}] ${options[$i]}"
    done

    echo -n "* Input 0-$((${#actions[@]} - 1)): "
    read -r action

    # Validate input
    if [[ -z "$action" ]] || [[ ! "$action" =~ ^[0-9]+$ ]] || [[ "$action" -lt 0 || "$action" -ge ${#actions[@]} ]]; then
      echo -e "\033[31mInvalid input. Please enter a valid option.\033[0m"
      continue
    fi

    done=true
    IFS=";" read -r i1 i2 <<<"${actions[$action]}"
    if [[ "$i1" == "install_dependencies" ]]; then
      install_dependencies
    else
      echo "Selected option: ${options[$action]}"
    fi
  done
}

# Cleanup function
cleanup() {
  echo "Cleaning up temporary files..."
  rm -f /tmp/lib.sh
  echo "Cleanup complete."
}

# Main script execution
LOG_PATH="/var/log/pterodactyl-installer.log"
welcome_message
prompt_password
main_menu
cleanup
