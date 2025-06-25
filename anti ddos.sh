#!/bin/bash

# Installer Script: DDoS Protection untuk VPS
# Fungsi: Mengkonfigurasi firewall dan memfilter IP mencurigakan
# Dibuat oleh: [Nama Anda]
# Versi: 1.0

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
   echo "Script ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

# Fungsi untuk memeriksa dan menginstall dependensi
install_dependencies() {
    echo "Memeriksa dan menginstall dependensi..."
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y iptables fail2ban net-tools
    elif [ -f /etc/redhat-release ]; then
        yum install -y iptables fail2ban net-tools
    else
        echo "Distribusi Linux tidak dikenali. Silakan install manual: iptables, fail2ban, net-tools"
        exit 1
    fi
}

# Fungsi untuk mengkonfigurasi firewall dasar
configure_firewall() {
    echo "Mengkonfigurasi firewall dasar..."

    # Flush existing rules
    iptables -F
    iptables -X

    # Set default policy
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow SSH (port 22, sesuaikan jika perlu)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # Allow HTTP/HTTPS (jika diperlukan)
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Protection against SYN floods
    iptables -N SYN_FLOOD
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    iptables -A SYN_FLOOD -m limit --limit 2/s --limit-burst 6 -j RETURN
    iptables -A SYN_FLOOD -j DROP

    # Limit connection attempts
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 3/minute --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j DROP

    # Protection against ping floods
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Save rules (tergantung distribusi)
    if [ -f /etc/debian_version ]; then
        iptables-save > /etc/iptables.rules
        echo "pre-up iptables-restore < /etc/iptables.rules" >> /etc/network/interfaces
    elif [ -f /etc/redhat-release ]; then
        service iptables save
        chkconfig iptables on
    fi
}

# Fungsi untuk mengkonfigurasi Fail2Ban
configure_fail2ban() {
    echo "Mengkonfigurasi Fail2Ban..."

    # Buat konfigurasi jail lokal
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
logpath = /var/log/auth.log
maxretry = 3

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = iptables-allports[name=recidive]
           sendmail-whois[name=recidive, dest=root@localhost]
bantime = 604800  ; 1 week
findtime = 86400  ; 1 day
maxretry = 5
EOF

    # Restart Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
}

# Fungsi untuk menginstall dan mengkonfigurasi CSF (ConfigServer Firewall)
install_csf() {
    echo "Menginstall CSF (ConfigServer Firewall)..."

    # Download dan install CSF
    cd /usr/src
    wget https://download.configserver.com/csf.tgz
    tar -xzf csf.tgz
    cd csf
    sh install.sh

    # Konfigurasi dasar CSF
    sed -i 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf
    sed -i 's/CT_LIMIT = "0"/CT_LIMIT = "300"/g' /etc/csf/csf.conf
    sed -i 's/CT_INTERVAL = "30"/CT_INTERVAL = "30"/g' /etc/csf/csf.conf
    sed -i 's/PORTFLOOD = ""/PORTFLOOD = "22;tcp;5;300"/g' /etc/csf/csf.conf
    sed -i 's/SYNFLOOD = "0"/SYNFLOOD = "1"/g' /etc/csf/csf.conf
    sed -i 's/SYNFLOOD_RATE = "100\/s"/SYNFLOOD_RATE = "50\/s"/g' /etc/csf/csf.conf
    sed -i 's/SYNFLOOD_BURST = "150"/SYNFLOOD_BURST = "100"/g' /etc/csf/csf.conf

    # Start CSF
    csf -r
    systemctl enable csf
    systemctl enable lfd
    systemctl restart csf
    systemctl restart lfd
}

# Fungsi untuk mengaktifkan kernel hardening
kernel_hardening() {
    echo "Mengaktifkan kernel hardening..."

    # Tambahkan parameter kernel ke sysctl.conf
    cat >> /etc/sysctl.conf <<EOF
# Kernel hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF

    # Terapkan perubahan
    sysctl -p
}

# Main execution
echo "Memulai instalasi konfigurasi keamanan VPS..."

# Install dependensi
install_dependencies

# Konfigurasi firewall
configure_firewall

# Konfigurasi Fail2Ban
configure_fail2ban

# Install CSF (opsional)
read -p "Install CSF (ConfigServer Firewall)? (y/n) " choice
if [[ "$choice" =~ [yY] ]]; then
    install_csf
fi

# Kernel hardening
kernel_hardening

echo ""
echo "Instalasi selesai!"
echo "VPS Anda sekarang telah dilengkapi dengan:"
echo "1. Firewall dasar dengan iptables"
echo "2. Fail2Ban untuk memblokir IP yang mencurigakan"
echo "3. (Opsional) CSF untuk perlindungan tambahan"
echo "4. Kernel hardening untuk mengurangi kerentanan DDoS"
echo ""
echo "Pastikan untuk menguji koneksi SSH Anda sebelum keluar!"