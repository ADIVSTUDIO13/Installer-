#!/bin/bash
# Full Real-Time Anti-DDoS Installer + Monitor + AutoBan + Notifikasi
# By ChatGPT for User

set -e

### ========== CEK AKSES ROOT ========== ###
if [[ $EUID -ne 0 ]]; then
    echo "Script ini harus dijalankan sebagai root!" 
    exit 1
fi

### ========== INPUT USER ========== ###
echo "=== Setting Konfigurasi Notifikasi Telegram ==="
read -p "Masukkan Bot Token Telegram Anda: " TELEGRAM_TOKEN
read -p "Masukkan Chat ID Telegram Anda: " TELEGRAM_CHAT_ID
echo ""
echo "Setting disimpan."

BAN_THRESHOLD=10

### ========== INSTALL PAKET ========== ###
echo "[+] Update & Install Paket..."
apt update && apt upgrade -y
apt install -y ufw fail2ban nginx crowdsec screen curl net-tools htop iftop jq -y

### ========== FIREWALL SETUP ========== ###
echo "[+] Firewall UFW Aktif..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

### ========== FAIL2BAN & CROWDSEC ========== ###
echo "[+] Setup Fail2Ban & CrowdSec..."
systemctl enable --now fail2ban
crowdsec collections install crowdsecurity/linux
cscli bouncers install crowdsec-firewall-bouncer-iptables
systemctl enable --now crowdsec

### ========== HARDENING KERNEL ========== ###
echo "[+] Setting Hardening Kernel..."
cat <<EOF >>/etc/sysctl.conf

# Anti DDOS
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=2
net.ipv4.conf.all.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
EOF
sysctl -p

### ========== SETUP NGINX CAPTCHA + LIMIT ========== ###
echo "[+] Setup Nginx Proteksi + CAPTCHA..."
mkdir -p /var/www/html/captcha

cat <<EOF >/var/www/html/captcha/index.html
<!DOCTYPE html><html><head><title>Verifikasi CAPTCHA</title><style>body{font-family:sans-serif;text-align:center;padding-top:50px;}button{padding:10px 20px;font-size:18px;}</style></head><body><h1>Verifikasi Anda Manusia</h1><p>Silakan klik untuk lanjut.</p><form method="GET" action="/"><button type="submit">Saya Bukan Robot</button></form></body></html>
EOF

cat <<EOF >/etc/nginx/conf.d/limit_req.conf
limit_req_zone \$binary_remote_addr zone=req_limit_per_ip:10m rate=1r/s;
limit_conn_zone \$binary_remote_addr zone=addr:10m;

server {
    listen 80 default_server;
    server_name _;

    location / {
        limit_req zone=req_limit_per_ip burst=5 nodelay;
        limit_conn addr 10;

        if (\$http_cookie !~ "passed=true") {
            return 302 /captcha/;
        }

        root /var/www/html;
        index index.html index.htm;
    }

    location /captcha/ {
        root /var/www/html;
        index index.html;
        add_header Set-Cookie "passed=true; Path=/";
    }

    if (\$http_user_agent ~* (sqlmap|nmap|nikto|fuzz|acunetix|curl|wget|bot|spider|crawler)) {
        return 403;
    }
}
EOF

cat <<EOF >/etc/nginx/conf.d/protect_slowloris.conf
client_body_timeout 10;
client_header_timeout 10;
keepalive_timeout 15;
send_timeout 10;
EOF

nginx -t && systemctl reload nginx

### ========== SETUP REAL-TIME MONITOR + AUTO BAN ========== ###
echo "[+] Membuat Script Realtime Monitor..."

mkdir -p /opt/realtime-ddos/

cat <<EOF >/opt/realtime-ddos/realtime-monitor.sh
#!/bin/bash

ACCESS_LOG="/var/log/nginx/access.log"

tail -Fn0 "\$ACCESS_LOG" | \
while read line; do
    ip=\$(echo "\$line" | awk '{print \$1}')
    if [[ "\$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if echo "\$line" | grep -q "/captcha/"; then
            count=\$(grep "\$ip" "\$ACCESS_LOG" | grep "/captcha/" | wc -l)
            if [ "\$count" -gt "$BAN_THRESHOLD" ]; then
                iptables -A INPUT -s "\$ip" -j DROP
                echo "[+] IP \$ip diban karena spam CAPTCHA."

                # Kirim Notifikasi Telegram
                curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage \
                -d chat_id=$TELEGRAM_CHAT_ID \
                -d text="IP \$ip diban karena spam CAPTCHA di server \$(hostname)."
            fi
        fi
    fi
done
EOF

chmod +x /opt/realtime-ddos/realtime-monitor.sh

### ========== SETUP SERVICE SYSTEMD ========== ###
echo "[+] Setup Systemd Service Realtime Monitor..."

cat <<EOF >/etc/systemd/system/realtime-monitor.service
[Unit]
Description=Real-Time Anti-DDoS Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/realtime-ddos/realtime-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now realtime-monitor.service

### ========== DONE ========== ###
echo ""
echo "=================================================="
echo "[+] Instalasi Selesai!"
echo "Server Proteksi: Firewall + Fail2Ban + CrowdSec + Nginx Hardening + Auto CAPTCHA + Realtime Ban + Notifikasi Telegram."
echo "=================================================="
