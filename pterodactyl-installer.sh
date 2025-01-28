#!/bin/bash

set -e

######################################################################################
# Project 'pterodactyl-installer'                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
######################################################################################

# Function to display a welcome message
welcome_message() {
  local cyan="\033[36m"
  local yellow="\033[33m"
  local reset="\033[0m"
  echo -e "${cyan}\n\nWelcome to the Pterodactyl installer by ARYASTORE!${reset}"
  echo -e "${yellow}This script will guide you through the installation process.${reset}\n"
}

# Prompt for password before proceeding
prompt_password() {
  echo -n "Enter password to continue: "
  read -s PASSWORD
  echo

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
  sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
enabled = true
EOF

  sudo systemctl enable fail2ban
  sudo systemctl restart fail2ban
  echo "Fail2Ban configuration complete."
}

# Setup UFW firewall rules
configure_ufw() {
  echo "Setting up UFW firewall..."
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  sudo ufw limit ssh
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw --force enable
  echo "UFW firewall configured."
}

# Enable TCP SYN Cookies
configure_syn_cookies() {
  echo "Configuring TCP SYN Cookies..."
  sudo sysctl -w net.ipv4.tcp_syncookies=1
  echo "net.ipv4.tcp_syncookies=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  echo "SYN Cookies protection is enabled."
}

# Apply sysctl hardening
configure_sysctl_hardening() {
  echo "Applying sysctl hardening..."
  sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
EOF

  sudo sysctl -p
  echo "Sysctl hardening applied."
}

# Enable automatic security updates
enable_auto_security_updates() {
  echo "Enabling automatic security updates..."
  sudo apt-get install -y unattended-upgrades
  sudo dpkg-reconfigure -plow unattended-upgrades
  echo "Automatic security updates enabled."
}

# Configure IPTables DDoS protection
configure_iptables_ddos_protection() {
  echo "Configuring IPTables for DDoS protection..."
  sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 5 -j ACCEPT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
  echo "IPTables DDoS protection applied."
}

# Send WhatsApp message using browser automation
send_whatsapp_message() {
  local phone_number="$1"
  local message="$2"

  echo "Opening WhatsApp Web..."
  
  xdg-open "https://web.whatsapp.com/send?phone=${phone_number}&text=${message}" &

  sleep 10

  echo "Waiting for user confirmation to send the message..."
  echo -e "\033[33mEnsure you are logged into WhatsApp Web.\033[0m"
  read -p "Press Enter once you've confirmed the message is ready to send..."
}

# Monitor server status and send WhatsApp notification
monitor_server() {
  local phone_number="$1"
  local server_ip="$2"
  local message="Server $server_ip is online and running normally."

  echo "Checking server status..."
  
  if ping -c 1 "$server_ip" &> /dev/null; then
    echo "Server is online."
    send_whatsapp_message "$phone_number" "$message"
  else
    echo "Server is offline!"
    send_whatsapp_message "$phone_number" "Server $server_ip is down. Please check immediately."
  fi
}

# Setup server monitoring
setup_server_monitoring() {
  echo -n "Enter the phone number (with country code): "
  read phone_number
  echo -n "Enter the server IP to monitor: "
  read server_ip

  echo "Monitoring server $server_ip and sending updates to $phone_number..."
  while true; do
    monitor_server "$phone_number" "$server_ip"
    sleep 60  # Check server status every minute
  done
}

# Main menu
main_menu() {
  local options=(
    "Install the panel"
    "Install Wings"
    "Configure Fail2Ban"
    "Configure UFW firewall"
    "Enable TCP SYN Cookies"
    "Apply sysctl hardening"
    "Enable automatic security updates"
    "Configure IPTables DDoS protection"
    "Monitor server and send WhatsApp message"
    "Exit"
  )

  local actions=(
    "install_panel"
    "install_wings"
    "configure_fail2ban"
    "configure_ufw"
    "configure_syn_cookies"
    "configure_sysctl_hardening"
    "enable_auto_security_updates"
    "configure_iptables_ddos_protection"
    "setup_server_monitoring"
    "exit 0"
  )

  while true; do
    echo -e "\033[36mSelect an option:\033[0m"
    for i in "${!options[@]}"; do
      echo -e "[$i] ${options[$i]}"
    done

    echo -n "* Input 0-$((${#actions[@]} - 1)): "
    read -r action

    if [[ "$action" =~ ^[0-9]+$ ]] && (( action >= 0 && action < ${#actions[@]} )); then
      eval "${actions[$action]}"
    else
      echo -e "\033[31mInvalid input. Please enter a valid option.\033[0m"
    fi
  done
}

# Install Panel (Placeholder)
install_panel() {
  echo "Installing Pterodactyl Panel... (Not implemented)"
}

# Install Wings (Placeholder)
install_wings() {
  echo "Installing Pterodactyl Wings... (Not implemented)"
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
