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
  echo "Fail2Ban SSH protection configured."
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

# Configure IPv6 Rate-Limiting
configure_ipv6_rate_limiting() {
  echo "Configuring IPv6 Rate-Limiting protection..."

  if sysctl net.ipv6.conf.all.disable_ipv6 | grep -q "1"; then
    echo -e "\033[31mIPv6 is disabled. Skipping configuration.\033[0m"
    return
  fi

  sudo ufw limit proto tcp from any to any port 80,443 comment 'Limit IPv6 HTTP/HTTPS traffic'
  echo "IPv6 Rate-Limiting protection is configured."
}

# Configure TCP SYN Cookies
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

# Main menu loop
main_menu() {
  local options=(
    "Install the panel"
    "Install Wings"
    "Install both Panel and Wings"
    "Configure Fail2Ban"
    "Configure UFW firewall"
    "Enable TCP SYN Cookies"
    "Configure IPv6 Rate-Limiting"
    "Configure Fail2Ban for SSH"
    "Apply sysctl hardening"
    "Enable automatic security updates"
    "Configure IPTables DDoS protection"
    "Exit"
  )

  local actions=(
    "install_panel"
    "install_wings"
    "install_panel; install_wings"
    "configure_fail2ban"
    "configure_ufw"
    "configure_syn_cookies"
    "configure_ipv6_rate_limiting"
    "configure_fail2ban_ssh"
    "configure_sysctl_hardening"
    "enable_auto_security_updates"
    "configure_iptables_ddos_protection"
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
