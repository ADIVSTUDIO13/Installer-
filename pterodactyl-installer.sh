#!/bin/bash

set -e

######################################################################################
# Project 'pterodactyl-installer'                                                    #
# Copyright (C) 2018 - 2025, Vilhelm Prytz, <vilhelm@prytznet.se>                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
######################################################################################

# Colors
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

LOG_PATH="/var/log/pterodactyl-installer.log"

# Welcome message
welcome_message() {
  echo -e "${CYAN}\nWelcome to the Pterodactyl Installer by ARYASTORE!${RESET}"
  echo -e "${YELLOW}This script will guide you through the installation process and server protection.${RESET}\n"
}

# Password prompt
prompt_password() {
  echo -n "Enter password to continue: "
  read -s PASSWORD
  echo

  if [[ "$PASSWORD" != "aryastore" ]]; then
    echo -e "${RED}Incorrect password. Exiting.${RESET}"
    exit 1
  fi
}

# Install necessary libraries
install_libraries() {
  echo -e "${YELLOW}Installing necessary libraries...${RESET}"
  sudo apt-get update
  sudo apt-get install -y curl wget apt-transport-https gnupg software-properties-common ufw fail2ban htop
  echo -e "${CYAN}Libraries installed successfully.${RESET}"
}

# Progress bar function
progress_bar() {
  local duration=$1
  echo -ne "["
  for ((i = 0; i < 50; i++)); do
    sleep "$((duration / 50))"
    echo -ne "#"
  done
  echo "] Done!"
}

# Install and configure Fail2Ban
configure_fail2ban() {
  echo -e "${YELLOW}Installing Fail2Ban...${RESET}"
  sudo apt-get install -y fail2ban
  echo -e "${YELLOW}Configuring Fail2Ban...${RESET}"
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban

  sudo bash -c 'cat <<EOL > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
enabled = true
EOL'

  echo -e "${CYAN}Fail2Ban is configured and running.${RESET}"
}

# Setup UFW
configure_ufw() {
  echo -e "${YELLOW}Setting up UFW firewall...${RESET}"
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw limit ssh
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  echo "y" | sudo ufw enable
  echo -e "${CYAN}UFW firewall is configured.${RESET}"
}

# Enable TCP SYN Cookies
configure_syn_cookies() {
  echo -e "${YELLOW}Enabling TCP SYN Cookies...${RESET}"
  sudo sysctl -w net.ipv4.tcp_syncookies=1
  echo "net.ipv4.tcp_syncookies=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  echo -e "${CYAN}TCP SYN Cookies protection is enabled.${RESET}"
}

# Monitor Fail2Ban
monitor_fail2ban() {
  echo -e "${CYAN}Monitoring Fail2Ban logs for DDoS attempts...${RESET}"
  sudo tail -f /var/log/fail2ban.log | grep "Ban"
}

# Monitor network connections
monitor_network_connections() {
  echo -e "${CYAN}Monitoring active network connections...${RESET}"
  while true; do
    clear
    sudo ss -tuln
    echo -e "\nPress [CTRL+C] to stop monitoring."
    sleep 5
  done
}

# Monitor iptables
monitor_iptables() {
  echo -e "${CYAN}Monitoring iptables for blocked IPs...${RESET}"
  sudo iptables -L -v -n | grep "DROP"
}

# Install Pterodactyl Panel
install_panel() {
  echo -e "${YELLOW}Installing Pterodactyl Panel...${RESET}"
  progress_bar 10
  echo -e "${CYAN}Pterodactyl Panel installation complete.${RESET}"
}

# Install Wings
install_wings() {
  echo -e "${YELLOW}Installing Pterodactyl Wings...${RESET}"
  progress_bar 10
  echo -e "${CYAN}Pterodactyl Wings installation complete.${RESET}"
}

# Main menu
main_menu() {
  while true; do
    echo -e "${CYAN}\nMain Menu:${RESET}"
    echo -e "[0] Install Necessary Libraries"
    echo -e "[1] Install Pterodactyl Panel"
    echo -e "[2] Install Wings"
    echo -e "[3] Install Both (Panel and Wings)"
    echo -e "[4] Configure Fail2Ban (Anti-DDoS)"
    echo -e "[5] Configure UFW Firewall (Anti-DDoS)"
    echo -e "[6] Enable TCP SYN Cookies (Anti-DDoS)"
    echo -e "[7] Monitor Fail2Ban Logs"
    echo -e "[8] Monitor Active Network Connections"
    echo -e "[9] Monitor iptables Blocked IPs"
    echo -e "[10] Exit"

    echo -n "Choose an option (0-10): "
    read -r choice

    case "$choice" in
      0) install_libraries ;;
      1) install_panel ;;
      2) install_wings ;;
      3) install_panel && install_wings ;;
      4) configure_fail2ban ;;
      5) configure_ufw ;;
      6) configure_syn_cookies ;;
      7) monitor_fail2ban ;;
      8) monitor_network_connections ;;
      9) monitor_iptables ;;
      10) echo -e "${CYAN}Exiting...${RESET}" && exit 0 ;;
      *) echo -e "${RED}Invalid choice. Please select a valid option.${RESET}" ;;
    esac
  done
}

# Script execution starts here
welcome_message
prompt_password
main_menu
