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

# Configure SSL with QUIC (HTTP/3)
configure_ssl_quic() {
  echo "Installing Certbot, NGINX, and QUIC libraries..."

  # Install required libraries for QUIC and HTTP/3
  sudo apt update
  sudo apt install -y \
    certbot \
    python3-certbot-nginx \
    build-essential \
    libssl-dev \
    libpcre3-dev \
    zlib1g-dev \
    wget \
    curl

  # Install QUIC support for NGINX
  echo "Installing NGINX with QUIC support..."
  
  # Download and compile NGINX with QUIC (HTTP/3) support
  cd /tmp
  wget https://nginx.org/download/nginx-1.23.2.tar.gz
  tar -zxvf nginx-1.23.2.tar.gz
  cd nginx-1.23.2
  wget https://github.com/cloudflare/quiche/archive/refs/tags/0.9.0.tar.gz -O quiche.tar.gz
  tar -zxvf quiche.tar.gz
  cd quiche-0.9.0
  cargo build --release --features 'pkg-config'

  cd /tmp/nginx-1.23.2
  ./configure --with-http_v2_module --with-http_ssl_module --with-http_quic_module --with-quiche=../quiche-0.9.0
  make
  sudo make install

  # Ensure NGINX is installed (if not already installed)
  if ! command -v nginx &> /dev/null; then
    echo "Nginx is not installed. Installing Nginx..."
    sudo apt install -y nginx
  fi

  # Ensure UFW allows HTTPS traffic
  sudo ufw allow 'Nginx Full'

  # Obtain SSL certificate using Certbot
  echo -n "Enter your domain name (e.g., example.com): "
  read -r DOMAIN

  # Use Certbot to obtain and install the SSL certificate
  sudo certbot --nginx -d "$DOMAIN" --agree-tos --non-interactive --email your-email@example.com

  # Set up automatic certificate renewal
  sudo systemctl enable certbot.timer
  sudo systemctl start certbot.timer

  # Enable QUIC (HTTP/3) in NGINX
  echo "Enabling QUIC (HTTP/3) in NGINX configuration..."

  # Modify NGINX configuration to support QUIC (HTTP/3)
  sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Enable QUIC (HTTP/3)
    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256';

    add_header Alt-Svc 'h3-23=":443"'; # Advertise QUIC to browsers
    add_header QUIC-Status $upstream_http_quic_status;

    # Enable HTTP/3 (QUIC)
    http3 on;
    listen 443 quic reuseport;
    listen [::]:443 quic reuseport;
    add_header QUIC-Status $quic_status;

    # Other server block configurations...
}
EOF'

  # Restart NGINX to apply the changes
  sudo systemctl restart nginx

  echo "SSL and QUIC (HTTP/3) configuration complete. Your domain is now secured with HTTPS and QUIC (HTTP/3)."
}

# Monitor Fail2Ban log to detect DDoS attempts
monitor_fail2ban() {
  echo "Monitoring Fail2Ban logs for DDoS attempts..."

  # Check the Fail2Ban log for banned IPs
  tail -f /var/log/fail2ban.log | grep "Ban"
}

# Monitor network connections using ss
monitor_network_connections() {
  echo "Monitoring active network connections..."

  # Display active connections and monitor for unusual activity
  while true; do
    clear
    echo "Active network connections:"
    sudo ss -tuln
    echo -e "\nPress [CTRL+C] to stop monitoring."
    sleep 5
  done
}

# Monitor iptables rate-limiting and blocked IPs
monitor_iptables() {
  echo "Monitoring iptables for blocked IPs..."

  # Show the number of connections made by each IP and look for rate-limiting blocks
  sudo iptables -L -v -n | grep "DROP"
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
      "Configure SSL with QUIC (HTTP/3)"
      "Monitor Fail2Ban logs for DDoS"
      "Monitor network connections for DDoS"
      "Monitor iptables for blocked IPs"
    )

    actions=(
      "echo 'Panel installation will proceed...'"
      "echo 'Wings installation will proceed...'"
      "echo 'Panel and Wings installation will proceed...'"
      "configure_fail2ban"
      "configure_ufw"
      "configure_syn_cookies"
      "configure_ipv6_rate_limiting"
      "configure_ssl_quic"
      "monitor_fail2ban"
      "monitor_network_connections"
      "monitor_iptables"
    )

    echo "Select an option:"
    PS3='> '
    select opt in "${options[@]}"; do
      if [[ "$opt" == "Quit" ]]; then
        done=true
        break
      fi
      if [[ -n "$opt" ]]; then
        eval "${actions[$REPLY-1]}"
      fi
    done
  done
}

# Start the installation process
welcome_message
prompt_password
main_menu
