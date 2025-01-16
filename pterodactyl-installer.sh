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

# Add Rate-Limiting IPv6 Protection
configure_ipv6_rate_limiting() {
  echo "Configuring IPv6 Rate-Limiting protection..."

  # Check if IPv6 is enabled
  if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "1"; then
    echo -e "\033[31mIPv6 is disabled on this system. Rate-limiting for IPv6 will not be applied.\033[0m"
    return
  fi

  # Add IPv6 rate-limiting rules in UFW
  sudo ufw allow proto tcp from any to any port 80,443 comment 'Allow HTTP/HTTPS traffic'
  sudo ufw allow proto udp from any to any port 80,443 comment 'Allow HTTP/HTTPS traffic'
  sudo ufw limit proto tcp from any to any port 80,443 comment 'Limit HTTP/HTTPS traffic'

  # Enable UFW rate-limiting for IPv6 (set the maximum new connections per minute)
  sudo sysctl -w net.ipv6.conf.all.accept_ra=0
  sudo sysctl -w net.ipv6.conf.default.accept_ra=0
  sudo sysctl -w net.ipv6.conf.all.rp_filter=1
  sudo sysctl -w net.ipv6.conf.default.rp_filter=1

  # Add rate limiting to UFW for IPv6
  sudo ufw limit proto tcp from any to any port 80,443 comment 'Limit IPv6 HTTP/HTTPS traffic'

  echo "IPv6 Rate-Limiting protection is configured."
}

# Configure TCP SYN Cookies to protect against SYN Flood attacks
configure_syn_cookies() {
  echo "Configuring TCP SYN Cookies..."

  # Check if SYN cookies are enabled, and enable them if not
  sysctl -w net.ipv4.tcp_syncookies=1
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
      "Configure IPv6 Rate-Limiting (Anti-DDoS)"
    )

    actions=(
      "panel"
      "wings"
      "panel;wings"
      "configure_fail2ban"
      "configure_ufw"
      "configure_syn_cookies"
      "configure_ipv6_rate_limiting"
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
    if [[ "$i1" == "configure_fail2ban" ]]; then
      configure_fail2ban
    elif [[ "$i1" == "configure_ufw" ]]; then
      configure_ufw
    elif [[ "$i1" == "configure_syn_cookies" ]]; then
      configure_syn_cookies
    elif [[ "$i1" == "configure_ipv6_rate_limiting" ]]; then
      configure_ipv6_rate_limiting
    else
      execute "$i1" "$i2"
    fi
  done
}

# Install and configure the main components (Pterodactyl Panel and Wings)
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

# Cleanup function
cleanup() {
  rm -f /tmp/lib.sh
}

# Main script execution
welcome_message
prompt_password
main_menu
cleanup
