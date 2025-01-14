#!/bin/bash

# Skrip Installer Pterodactyl dengan Menu Pilihan dan Fitur Tambahan

# Periksa hak akses root
if [ "$EUID" -ne 0 ]; then
    echo "Silakan jalankan skrip ini sebagai root."
    exit
fi

# Cek koneksi internet
check_internet() {
    echo "Memeriksa koneksi internet..."
    if ! ping -c 1 google.com &>/dev/null; then
        echo "Koneksi internet tidak tersedia. Pastikan server terhubung ke internet."
        exit 1
    fi
}

# Cek ruang disk dan memori
check_resources() {
    echo "Memeriksa ruang disk dan memori..."
    DISK_SPACE=$(df / | grep / | awk '{ print $4 }')
    MEMORY=$(free -m | grep Mem | awk '{ print $2 }')

    if [ "$DISK_SPACE" -lt 1000000 ]; then
        echo "Peringatan: Ruang disk kurang dari 1GB, pastikan ada cukup ruang disk untuk instalasi."
    fi

    if [ "$MEMORY" -lt 1024 ]; then
        echo "Peringatan: Memori kurang dari 1GB, pastikan ada cukup memori untuk menjalankan panel."
    fi
}

# Fungsi untuk instalasi dependensi dasar dengan timeout
install_dependencies() {
    echo "1. Memperbarui sistem dan menginstal dependensi..."
    timeout 600 apt update && apt upgrade -y
    timeout 600 apt install -y curl zip unzip tar wget git nginx mariadb-server software-properties-common ufw
}

# Fungsi untuk menginstal PHP dan Composer dengan timeout
install_php_composer() {
    echo "2. Menginstal PHP dan Composer..."
    timeout 600 add-apt-repository -y ppa:ondrej/php
    timeout 600 apt update
    timeout 600 apt install -y php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-bcmath php8.1-json php8.1-common php8.1-tokenizer php8.1-zip
    timeout 600 curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

# Fungsi untuk mengatur database dengan timeout
setup_database() {
    echo "3. Mengatur database untuk Pterodactyl..."
    DB_PASSWORD=$(openssl rand -base64 12)
    timeout 600 mysql -e "CREATE DATABASE panel;"
    timeout 600 mysql -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    timeout 600 mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
    timeout 600 mysql -e "FLUSH PRIVILEGES;"
    echo "Informasi database:"
    echo "Nama Database: panel"
    echo "User: pterodactyl"
    echo "Password: ${DB_PASSWORD}"
}

# Fungsi untuk instalasi Pterodactyl Panel dengan timeout
install_panel() {
    echo "4. Menginstal Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    timeout 600 curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    timeout 600 tar -xzvf panel.tar.gz && rm panel.tar.gz
    timeout 600 composer install --no-dev --optimize-autoloader
    timeout 600 cp .env.example .env
    timeout 600 php artisan key:generate --force
    timeout 600 php artisan p:environment:setup
    timeout 600 php artisan p:environment:database
    timeout 600 php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl
    chmod -R 755 /var/www/pterodactyl
}

# Fungsi untuk mengonfigurasi Nginx dengan timeout
setup_nginx() {
    echo "5. Mengonfigurasi Nginx..."
    # Jika hanya menginstal panel, hanya perlu meminta domain utama
    if [ "$INSTALL_WINGS" != "true" ]; then
        echo "Masukkan domain utama Anda (tanpa http/https): "
        read DOMAIN
    else
        # Jika Wings juga diinstal, domain tetap diminta
        echo "Masukkan domain utama untuk Panel dan Wings (tanpa http/https): "
        read DOMAIN
    fi

    echo "server {
        listen 80;
        server_name $DOMAIN;

        root /var/www/pterodactyl/public;

        index index.php;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ /\.ht {
            deny all;
        }
    }" > /etc/nginx/sites-available/pterodactyl

    ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
    timeout 600 nginx -t && systemctl restart nginx
    ufw allow 'Nginx Full'
}

# Fungsi untuk instalasi Wings dengan timeout
install_wings() {
    echo "6. Menginstal Wings..."
    timeout 600 curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    mkdir -p /etc/pterodactyl
    echo "[Unit]
    Description=Pterodactyl Wings Daemon
    After=network.target

    [Service]
    User=root
    WorkingDirectory=/etc/pterodactyl
    ExecStart=/usr/local/bin/wings
    Restart=on-failure
    StartLimitInterval=600

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/wings.service
    systemctl enable wings
    systemctl start wings
}

# Pengaturan firewall lebih lanjut (misalnya membatasi akses SSH)
setup_firewall() {
    echo "7. Mengonfigurasi firewall..."
    ufw allow OpenSSH
    ufw enable
    ufw allow 'Nginx Full'
}

# Menu utama
while true; do
    clear
    echo "=============================="
    echo "Installer Pterodactyl Panel + Wings"
    echo "=============================="
    echo "Pilih opsi:"
    echo "0. Instal semua (Panel + Wings + Pengaturan tambahan)"
    echo "1. Instal Pterodactyl Panel saja"
    echo "2. Instal Wings saja"
    echo "3. Keluar"
    echo "=============================="
    read -p "Masukkan pilihan Anda: " choice

    case $choice in
        0)
            INSTALL_WINGS=true
            check_internet
            check_resources
            install_dependencies
            install_php_composer
            setup_database
            install_panel
            setup_nginx
            install_wings
            setup_firewall
            echo "Instalasi selesai!"
            break
            ;;
        1)
            INSTALL_WINGS=false
            check_internet
            check_resources
            install_dependencies
            install_php_composer
            setup_database
            install_panel
            setup_nginx
            echo "Panel telah diinstal!"
            break
            ;;
        2)
            INSTALL_WINGS=true
            check_internet
            check_resources
            install_wings
            echo "Wings telah diinstal!"
            break
            ;;
        3)
            echo "Keluar..."
            exit
            ;;
        *)
            echo "Pilihan tidak valid. Silakan coba lagi."
            ;;
    esac
done
