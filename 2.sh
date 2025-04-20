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

# Generate random admin username
generate_admin_username() {
    local prefix="admin"
    local random_chars=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
    echo "${prefix}_${random_chars}"
}

# Menu untuk memilih fitur dengan warna
echo -e "\033[1;33mPilih fitur yang ingin Anda instal:\033[0m"
echo -e "\033[1;34m1.\033[0m Instal Panel Pterodactyl"
echo -e "\033[1;34m2.\033[0m Instal Wings dan Node.js"
echo -e "\033[1;34m3.\033[0m Semua di atas (Panel, Wings, Node.js)"

# Meminta input dari pengguna dengan warna
read -p $'\033[1;36mMasukkan nomor pilihan Anda (1-3): \033[0m' pilihan

# Deklarasi variabel
panel_subdomain=""
wings_subdomain=""
panel_ssl=""
wings_ssl=""

# Meminta input subdomain untuk Panel dan Wings
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    read -p $'\033[1;36mMasukkan subdomain untuk Panel (misalnya: panel.domain.com): \033[0m' panel_subdomain
    read -p $'\033[1;36mGunakan SSL untuk Panel? (y/n): \033[0m' panel_ssl
fi
if [[ "$pilihan" == "2" || "$pilihan" == "3" ]]; then
    read -p $'\033[1;36mMasukkan subdomain untuk Wings (misalnya: node.domain.com): \033[0m' wings_subdomain
    read -p $'\033[1;36mGunakan SSL untuk Wings? (y/n): \033[0m' wings_ssl
fi

# Memastikan subdomain tidak kosong berdasarkan pilihan
if [[ ("$pilihan" == "1" || "$pilihan" == "3") && -z "$panel_subdomain" ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Subdomain Panel tidak boleh kosong! Skrip dihentikan."
    exit 1
fi

if [[ ("$pilihan" == "2" || "$pilihan" == "3") && -z "$wings_subdomain" ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Subdomain Wings tidak boleh kosong! Skrip dihentikan."
    exit 1
fi

# Generate admin credentials
admin_username=$(generate_admin_username)
admin_email="${admin_username}@${panel_subdomain}"
admin_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

# Konversi input SSL ke lowercase
panel_ssl=${panel_ssl,,}
wings_ssl=${wings_ssl,,}

# Update dan upgrade sistem
echo -e "\n\033[1;32m[INFO]\033[0m Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Install dependensi yang dibutuhkan
echo -e "\033[1;32m[INFO]\033[0m Menginstal dependensi yang diperlukan..."
apt install -y curl wget sudo unzip zip git bash-completion apt-transport-https ca-certificates lsb-release gnupg jq

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
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Instal Panel Pterodactyl jika dipilih
if [[ "$pilihan" == "1" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Menginstal Pterodactyl Panel..."
    
    # Install PHP dan dependensi
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
    apt install -y php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    # Konfigurasi MySQL
    echo -e "\033[1;32m[INFO]\033[0m Mengkonfigurasi database..."
    mysql -e "CREATE DATABASE panel;"
    mysql -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'Pterodactyl@123';"
    mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Download Panel
    echo -e "\033[1;32m[INFO]\033[0m Mengunduh Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache
    
    # Install dependencies
    echo -e "\033[1;32m[INFO]\033[0m Menginstal dependencies Composer..."
    cp .env.example .env
    composer install --no-dev --optimize-autoloader --no-interaction
    
    # Generate key
    echo -e "\033[1;32m[INFO]\033[0m Generate application key..."
    php artisan key:generate --force
    
    # Setup environment
    echo -e "\033[1;32m[INFO]\033[0m Konfigurasi environment..."
    php artisan p:environment:setup \
        --author=${admin_email} \
        --url=http${([[ "$panel_ssl" == "y" ]] && echo "s")}://${panel_subdomain} \
        --timezone=Asia/Jakarta \
        --cache=redis \
        --session=redis \
        --queue=redis \
        --redis-host=127.0.0.1 \
        --redis-pass="" \
        --redis-port=6379 \
        --db-host=127.0.0.1 \
        --db-port=3306 \
        --db-name=panel \
        --db-user=pterodactyl \
        --db-pass="Pterodactyl@123" \
        --no-interaction
    
    # Setup database
    echo -e "\033[1;32m[INFO]\033[0m Migrasi database..."
    php artisan migrate --seed --force
    
    # Buat user admin pertama
    echo -e "\033[1;32m[INFO]\033[0m Membuat user admin..."
    php artisan p:user:make \
        --email=${admin_email} \
        --username=${admin_username} \
        --name-first=Admin \
        --name-last=Panel \
        --password=${admin_password} \
        --admin=1
    
    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl/*
    
    # Setup queue worker
    echo -e "\033[1;32m[INFO]\033[0m Setup cron job..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    # Setup systemd service
    echo -e "\033[1;32m[INFO]\033[0m Setup queue worker..."
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now pteroq.service
    systemctl enable --now redis-server
fi

# Instal Nginx jika diperlukan
if [[ ("$pilihan" == "1" || "$pilihan" == "3") && -n "$panel_subdomain" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Mengkonfigurasi Nginx..."
    
    # Konfigurasi Nginx untuk Panel
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $panel_subdomain;

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # Increase file upload size
    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M \n max_execution_time=300 \n max_input_time=300";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx
    systemctl restart php8.1-fpm
fi

# Instal SSL Let's Encrypt untuk Panel jika dipilih
if [[ ("$pilihan" == "1" || "$pilihan" == "3") && -n "$panel_subdomain" && "$panel_ssl" == "y" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi SSL untuk Panel..."
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $panel_subdomain --non-interactive --agree-tos -m ${admin_email} --redirect
    systemctl restart nginx
fi

# Instal Wings dan Node.js jika dipilih
if [[ "$pilihan" == "2" || "$pilihan" == "3" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Menginstal Node.js dan Wings..."
    
    # Install Node.js
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt install -y nodejs
    
    # Install Wings
    mkdir -p /etc/pterodactyl
    curl -sSL https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
    chmod +x /usr/local/bin/wings

    # Menentukan skema berdasarkan pilihan SSL
    wings_scheme="http"
    if [[ "$wings_ssl" == "y" ]]; then
        wings_scheme="https"
    fi

    # Setup Wings dan konfigurasi dengan domain Wings
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi Wings..."
    cat > /etc/pterodactyl/config.yml <<EOF
service:
  listen: "0.0.0.0:8080"
  websocket: "0.0.0.0:8081"
  max_memory: 4096

panel:
  host: "$panel_subdomain"
  scheme: "$wings_scheme"
  port: "$([[ "$wings_ssl" == "y" ]] && echo "443" || echo "80")"

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
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # Memulai Wings
    systemctl daemon-reload
    systemctl enable --now wings
fi

# Instal SSL Let's Encrypt untuk Wings jika dipilih
if [[ ("$pilihan" == "2" || "$pilihan" == "3") && -n "$wings_subdomain" && "$wings_ssl" == "y" ]]; then
    echo -e "\033[1;32m[INFO]\033[0m Mengonfigurasi SSL untuk Wings..."
    certbot --nginx -d $wings_subdomain --non-interactive --agree-tos -m ${admin_email} --redirect
    systemctl restart nginx
fi

# Selesai dengan penutupan yang lebih menarik
echo -e "\n\033[1;32m[INFO]\033[0m Instalasi selesai!"
if [[ -n "$panel_subdomain" ]]; then
    echo -e "\033[1;33mPanel dapat diakses di:\033[0m $([[ "$panel_ssl" == "y" ]] && echo "https" || echo "http")://$panel_subdomain"
    echo -e "\033[1;33mAdmin Panel:\033[0m"
    echo -e "\033[1;36mUsername:\033[0m $admin_username"
    echo -e "\033[1;36mPassword:\033[0m $admin_password"
    echo -e "\033[1;36mEmail:\033[0m $admin_email"
fi
if [[ -n "$wings_subdomain" ]]; then
    echo -e "\033[1;33mWings dapat diakses di:\033[0m $([[ "$wings_ssl" == "y" ]] && echo "https" || echo "http")://$wings_subdomain"
fi
echo -e "\n\033[1;34mTerima kasih telah menggunakan Pterodactyl Installer!\033[0m"