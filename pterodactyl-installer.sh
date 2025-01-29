#!/bin/bash

set -e

######################################################################################
# Project 'pterodactyl-installer'                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
######################################################################################

# Telegram bot token and chat ID
TELEGRAM_TOKEN="8045959585:AAHBx6-TG9py2L-QI8ryFsQJ3Z-mJQJh7sY"
TELEGRAM_CHAT_ID="6143977018"

# Function to send message to Telegram
send_telegram_message() {
  local message="$1"
  local url="https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"
  curl -s -X POST "$url" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$message"
}

# Function to display a welcome message with ASCII art logo
welcome_message() {
  local cyan="\033[36m"
  local yellow="\033[33m"
  local reset="\033[0m"

  # ASCII art for Linux OS
  echo -e "${cyan}\n\n
   __      ________   __     __  _______     __
  /  \    /  /\   |  /  \   /  |/  /    |   /  \\
 / /\ \  /  /  |  / /\ \_/ / /  /     |  / /\ \\
/ /  \ \/  /|  | / /  \   / /  /   |   / /  \ \\
/_/    \_/  /|  |/_/    \_/  /_/   | /_/    \_/ 
                 \033[36mLinux Pterodactyl Installer\033[0m
${reset}"

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
  send_telegram_message "Fail2Ban has been configured."
  echo "Fail2Ban configuration complete."
}

# Uninstall Fail2Ban
uninstall_fail2ban() {
  echo "Uninstalling Fail2Ban..."
  sudo systemctl stop fail2ban
  sudo systemctl disable fail2ban
  sudo apt-get remove --purge -y fail2ban
  sudo rm -f /etc/fail2ban/jail.local
  send_telegram_message "Fail2Ban has been uninstalled."
  echo "Fail2Ban has been uninstalled."
}

# Configure Fail2Ban for SSH
configure_fail2ban_ssh() {
  echo "Configuring Fail2Ban for SSH..."
  sudo tee /etc/fail2ban/jail.d/ssh.conf > /dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

  sudo systemctl restart fail2ban
  send_telegram_message "Fail2Ban SSH protection configured."
  echo "Fail2Ban SSH protection configured."
}

# Uninstall UFW
uninstall_ufw() {
  echo "Uninstalling UFW..."
  sudo ufw --force reset
  sudo apt-get remove --purge -y ufw
  send_telegram_message "UFW has been uninstalled."
  echo "UFW has been uninstalled."
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
  send_telegram_message "UFW firewall has been configured."
  echo "UFW firewall configured."
}

# Uninstall IPv6 Rate-Limiting
uninstall_ipv6_rate_limiting() {
  echo "Removing IPv6 Rate-Limiting rules..."
  sudo ufw delete limit proto tcp from any to any port 80,443
  send_telegram_message "IPv6 Rate-Limiting protection removed."
  echo "IPv6 Rate-Limiting protection removed."
}

# Configure IPv6 Rate-Limiting
configure_ipv6_rate_limiting() {
  echo "Configuring IPv6 Rate-Limiting protection..."

  if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "1"; then
    echo -e "\033[31mIPv6 is disabled. Skipping configuration.\033[0m"
    return
  fi

  sudo ufw limit proto tcp from any to any port 80,443 comment 'Limit IPv6 HTTP/HTTPS traffic'
  send_telegram_message "IPv6 Rate-Limiting protection configured."
  echo "IPv6 Rate-Limiting protection is configured."
}

# Uninstall TCP SYN Cookies
uninstall_syn_cookies() {
  echo "Removing TCP SYN Cookies..."
  sudo sysctl -w net.ipv4.tcp_syncookies=0
  sudo sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
  sudo sysctl -p
  send_telegram_message "SYN Cookies protection removed."
  echo "SYN Cookies protection removed."
}

# Configure TCP SYN Cookies
configure_syn_cookies() {
  echo "Configuring TCP SYN Cookies..."
  sudo sysctl -w net.ipv4.tcp_syncookies=1
  echo "net.ipv4.tcp_syncookies=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  send_telegram_message "SYN Cookies protection enabled."
  echo "SYN Cookies protection is enabled."
}

# Apply sysctl hardening
configure_sysctl_hardening() {
  echo "Applying sysctl hardening..."
  sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# Prevent SYN flood attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

  sudo sysctl -p
  send_telegram_message "Sysctl hardening applied."
  echo "Sysctl hardening applied."
}

# Enable automatic security updates
enable_auto_security_updates() {
  echo "Enabling automatic security updates..."
  sudo apt-get install -y unattended-upgrades
  sudo dpkg-reconfigure -plow unattended-upgrades
  send_telegram_message "Automatic security updates enabled."
  echo "Automatic security updates enabled."
}

# Uninstall automatic security updates
uninstall_auto_security_updates() {
  echo "Uninstalling automatic security updates..."
  sudo apt-get remove --purge -y unattended-upgrades
  send_telegram_message "Automatic security updates uninstalled."
  echo "Automatic security updates uninstalled."
}

# Uninstall IPTables DDoS protection
uninstall_iptables_ddos_protection() {
  echo "Removing IPTables DDoS protection..."
  sudo iptables -D INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -D INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -D INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 5 -j ACCEPT
  sudo iptables -D INPUT -p icmp --icmp-type echo-request -j DROP
  send_telegram_message "IPTables DDoS protection removed."
  echo "IPTables DDoS protection removed."
}

# Configure IPTables DDoS protection
configure_iptables_ddos_protection() {
  echo "Configuring IPTables for DDoS protection..."
  sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 5 -j ACCEPT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
  send_telegram_message "IPTables DDoS protection applied."
  echo "IPTables DDoS protection applied."
}

# Main menu loop
main_menu() {
  local options=(
    "Install the panel"
    "Install Wings"
    "Install both Panel and Wings"
    "Configure Fail2Ban"
    "Uninstall Fail2Ban"
    "Configure UFW firewall"
    "Uninstall UFW"
    "Enable TCP SYN Cookies"
    "Uninstall TCP SYN Cookies"
    "Configure IPv6 Rate-Limiting"
    "Uninstall IPv6 Rate-Limiting"
    "Configure Fail2Ban for SSH"
    "Apply sysctl hardening"
    "Enable automatic security updates"
    "Uninstall automatic security updates"
    "Configure IPTables DDoS protection"
    "Uninstall IPTables DDoS protection"
    "Exit"
  )

  local actions=(
    "install_panel"
    "install_wings"
    "install_panel; install_wings"
    "configure_fail2ban"
    "uninstall_fail2ban"
    "configure_ufw"
    "uninstall_ufw"
    "configure_syn_cookies"
    "uninstall_syn_cookies"
    "configure_ipv6_rate_limiting"
    "uninstall_ipv6_rate_limiting"
    "configure_fail2ban_ssh"
    "configure_sysctl_hardening"
    "enable_auto_security_updates"
    "uninstall_auto_security_updates"
    "configure_iptables_ddos_protection"
    "uninstall_iptables_ddos_protection"
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
