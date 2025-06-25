#!/bin/bash

# ==============================================
# ULTIMATE VPS PROTECTION & DOCKER FIX SCRIPT
# ==============================================
# Fungsi:
# 1. Perlindungan DDoS (iptables, fail2ban, CSF, kernel hardening)
# 2. Perbaikan error Docker networking di Pterodactyl
# Versi: 3.0

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
   echo "ERROR: Script harus dijalankan sebagai root!" 1>&2
   exit 1
fi

# ========================
# FUNGSI UTAMA
# ========================

function header() {
    clear
    echo -e "\n\033[1;36m======================================="
    echo "|   Ultimate VPS Protection Script   |"
    echo "======================================="
    echo -e "| Versi: 3.0 | Author: @zerocode74 |\033[0m"
    echo -e "=======================================\n"
}

function install_dependencies() {
    echo -e "\033[1;33m[1] INSTALL DEPENDENSI...\033[0m"
    
    # Install paket dasar
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y iptables fail2ban net-tools wget curl docker.io
    elif [ -f /etc/redhat-release ]; then
        yum install -y iptables fail2ban net-tools wget curl docker
    else
        echo "ERROR: Distro Linux tidak dikenali!"
        exit 1
    fi
    
    echo -e "\033[1;32m✓ Dependensi terinstall\033[0m"
}

function configure_firewall() {
    echo -e "\n\033[1;33m[2] KONFIGURASI FIREWALL...\033[0m"
    
    # Backup iptables
    iptables-save > /etc/iptables.backup
    
    # Flush existing rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X

    # Basic rules
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Protection rules
    iptables -N SYN_FLOOD
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    iptables -A SYN_FLOOD -m limit --limit 2/s --limit-burst 6 -j RETURN
    iptables -A SYN_FLOOD -j DROP
    
    # Docker-specific chains
    iptables -t nat -N DOCKER
    iptables -t filter -N DOCKER
    iptables -t filter -N DOCKER-ISOLATION-STAGE-1
    iptables -t filter -N DOCKER-ISOLATION-STAGE-2
    iptables -t filter -N DOCKER-USER
    
    echo -e "\033[1;32m✓ Firewall terkofigurasi\033[0m"
}

function fix_docker_networking() {
    echo -e "\n\033[1;33m[3] MEMPERBAIKI DOCKER NETWORKING...\033[0m"
    
    # Restart docker
    systemctl restart docker
    
    # Rebuild network
    docker network prune -f
    docker network create --subnet=172.18.0.0/16 pterodactyl_nw
    
    # Update docker config
    cat > /etc/docker/daemon.json <<EOF
{
  "iptables": true,
  "ip-masq": true,
  "bip": "172.18.0.1/16"
}
EOF
    
    systemctl daemon-reload
    systemctl restart docker
    
    echo -e "\033[1;32m✓ Docker networking diperbaiki\033[0m"
}

function configure_fail2ban() {
    echo -e "\n\033[1;33m[4] KONFIGURASI FAIL2BAN...\033[0m"
    
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3

[docker-iptables]
enabled = true
filter = docker-iptables
logpath = /var/log/docker.log
maxretry = 5
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    echo -e "\033[1;32m✓ Fail2Ban terkofigurasi\033[0m"
}

function kernel_hardening() {
    echo -e "\n\033[1;33m[5] KERNEL HARDENING...\033[0m"
    
    cat > /etc/sysctl.d/99-hardening.conf <<EOF
# Kernel hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv6.conf.all.accept_redirects = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-hardening.conf
    
    echo -e "\033[1;32m✓ Kernel hardening diterapkan\033[0m"
}

function verify_installation() {
    echo -e "\n\033[1;33m[6] VERIFIKASI...\033[0m"
    
    echo -e "\n\033[1;34m=== Status Iptables ===\033[0m"
    iptables -L -n -v
    
    echo -e "\n\033[1;34m=== Status Docker ===\033[0m"
    docker network ls
    systemctl status docker --no-pager
    
    echo -e "\n\033[1;34m=== Status Fail2Ban ===\033[0m"
    fail2ban-client status
    
    echo -e "\n\033[1;32m✓ Verifikasi selesai\033[0m"
}

# ========================
# EKSEKUSI SCRIPT
# ========================
header
install_dependencies
configure_firewall
fix_docker_networking
configure_fail2ban
kernel_hardening
verify_installation

echo -e "\n\033[1;36m======================================="
echo " SCRIPT SELESAI DIJALANKAN!"
echo " Rekomendasi:"
echo " 1. Test koneksi SSH dan Docker"
echo " 2. Monitor log dengan:"
echo "    tail -f /var/log/fail2ban.log"
echo -e "=======================================\033[0m\n"