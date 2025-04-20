#!/bin/bash

# Memastikan script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Harap jalankan script ini sebagai root atau menggunakan sudo."
    exit 1
fi

# Menampilkan pesan selamat datang dengan warna
clear
echo -e "\033[1;34m===============================\033[0m"
echo -e "\033[1;32mSelamat datang di Installer Pterodactyl!\033[0m"
echo -e "\033[1;34m===============================\033[0m"
echo -e "\nScript ini akan menginstal Pterodactyl Panel, Wings, dan Node.js."
echo -e "Pastikan server VPS Anda memiliki minimal 4 GB RAM dan akses root.\n"

# Menu untuk memilih fitur dengan warna
echo -e "\033[1;33mPilih fitur yang ingin Anda instal:\033[0m"
echo -e "\033[1;34m1.\033[0m Instal Panel Pterodactyl"
echo -e "\033[1;34m2.\033[0m Instal Wings dan Node.js"
echo -e "\033[1;34m3.\033[0m Semua di atas (Panel, Wings, Node.js)"

# Meminta input dari pengguna dengan warna
read -p $'\033[1;36mMasukkan nomor pilihan Anda (1-3): \033[0m' pilihan

# Meminta input subdomain untuk Panel dan Wings
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    read -p $'\033[1;36mMasukkan subdomain untuk Panel (misalnya: panel.aryastore.me): \033[0m' panel_subdomain
fi
if [[ "$pilihan" == "2" || "$pilihan" == "3" ]]; then
    read -p $'\033[1;36mMasukkan subdomain untuk Wings (misalnya: node.aryastore.me): \033[0m' wings_subdomain
fi

# Memastikan subdomain tidak kosong
if [[ -z "$panel_subdomain" || -z "$wings_subdomain" ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Subdomain tidak boleh kosong! Skrip dihentikan."
    exit 1
fi

# Update dan upgrade sistem
echo -e "\n\033[1;32m[INFO]\033[0m Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Install dependensi yang dibutuhkan
echo -e "\033[1;32m[INFO]\033[0m Menginstal dependensi yang diperlukan..."
apt install -y curl wget sudo unzip zip git bash-completion apt-transport-https ca-certificates lsb-release

# Install Docker jika dipilih
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Menginstal Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

# Install Docker Compose jika dipilih
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Menginstal Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Instal Wings dan Node.js jika dipilih
if [[ "$pilihan" == "2" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Menginstal Node.js dan Wings..."
    
    # Install Node.js
    curl -sL https://deb.nodesource.com/setup_16.x | bash
    apt install -y nodejs
    
    # Install Wings
    curl -sSL https://github.com/pterodactyl/wings/releases/download/v1.9.0/wings-linux-amd64.tar.gz -o wings.tar.gz
    tar -xvzf wings.tar.gz -C /usr/local/bin
    rm wings.tar.gz

    # Membuat folder konfigurasi Wings
    mkdir -p /etc/pterodactyl

    # Setup Wings dan konfigurasi dengan domain Wings
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi Wings dengan subdomain $wings_subdomain..."
    cat > /etc/pterodactyl/config.yml <<EOF
service:
  listen: "0.0.0.0:8080"
  websocket: "0.0.0.0:8081"
  max_memory: 4096

panel:
  host: "$panel_subdomain"
  scheme: "https"
  port: "443"

security:
  trusted_proxies:
    - "0.0.0.0/0"
  access_control:
    - "127.0.0.1"
    - "::1"
EOF

    # Membuat file systemd untuk Wings
    cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings
After=network.target

[Service]
ExecStart=/usr/local/bin/wings
WorkingDirectory=/etc/pterodactyl
User=root
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # Memulai Wings
    systemctl enable wings
    systemctl start wings
fi

# Instal SSL Let's Encrypt untuk Panel jika dipilih
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi SSL untuk Panel menggunakan Let's Encrypt..."
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $panel_subdomain --non-interactive --agree-tos -m admin@$panel_subdomain
fi

# Instal SSL Let's Encrypt untuk Wings jika dipilih
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi SSL untuk Wings menggunakan Let's Encrypt..."
    certbot --nginx -d $wings_subdomain --non-interactive --agree-tos -m admin@$wings_subdomain
fi

# Selesai dengan penutupan yang lebih menarik
echo -e "\n\033[1;32m[INFO]\033[0m Instalasi selesai!"
echo -e "\033[1;33mPanel dapat diakses di:\033[0m https://$panel_subdomain"
echo -e "\033[1;33mWings dapat diakses di:\033[0m https://$wings_subdomain"
echo -e "\n\033[1;34mTerima kasih telah menggunakan Pterodactyl Installer!\033[0m"
