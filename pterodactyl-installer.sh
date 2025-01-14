#!/bin/bash

# Skrip Installer Pterodactyl dengan Menu Pilihan, Akun Admin Default, dan Domain Utama serta Node

# Periksa hak akses root
if [ "$EUID" -ne 0 ]; then
    echo "Silakan jalankan skrip ini sebagai root."
    exit
fi

# Fungsi untuk instalasi dependensi dasar
install_dependencies() {
    echo "1. Memperbarui sistem dan menginstal dependensi..."
    apt update && apt upgrade -y
    apt install -y curl zip unzip tar wget git nginx mariadb-server software-properties-common ufw
}

# Fungsi untuk menginstal PHP dan Composer
install_php_composer() {
    echo "2. Menginstal PHP dan Composer..."
    add-apt-repository -y ppa:ondrej/php
    apt update
    apt install -y php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-bcmath php8.1-json php8.1-common php8.1-tokenizer php8.1-zip
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

# Fungsi untuk mengatur database
setup_database() {
    echo "3. Mengatur database untuk Pterodactyl..."
    DB_PASSWORD=$(openssl rand -base64 12)
    mysql -e "CREATE DATABASE panel;"
    mysql -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    echo "Informasi database:"
    echo "Nama Database: panel"
    echo "User: pterodactyl"
    echo "Password: ${DB_PASSWORD}"
}

# Fungsi untuk instalasi Pterodactyl Panel
install_panel() {
    echo "4. Menginstal Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz && rm panel.tar.gz
    composer install --no-dev --optimize-autoloader
    cp .env.example .env
    php artisan key:generate --force
    php artisan p:environment:setup
    php artisan p:environment:database
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl
    chmod -R 755 /var/www/pterodactyl
}

# Fungsi untuk mengonfigurasi Nginx
setup_nginx() {
    echo "5. Mengonfigurasi Nginx..."
    
    # Meminta input domain utama dan node
    echo "Masukkan domain utama Anda (tanpa http/https): "
    read MAIN_DOMAIN
    echo "Masukkan domain node Anda (tanpa http/https): "
    read NODE_DOMAIN

    # Konfigurasi Nginx untuk domain utama
    echo "server {
        listen 80;
        server_name $MAIN_DOMAIN;

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

    # Konfigurasi Nginx untuk domain node
    echo "server {
        listen 80;
        server_name $NODE_DOMAIN;

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
    }" > /etc/nginx/sites-available/node

    # Membuat symbolic links agar Nginx menggunakan konfigurasi tersebut
    ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
    ln -s /etc/nginx/sites-available/node /etc/nginx/sites-enabled/
    
    # Menguji konfigurasi dan merestart Nginx
    nginx -t && systemctl restart nginx
    ufw allow 'Nginx Full'
}

# Fungsi untuk instalasi Wings
install_wings() {
    echo "6. Menginstal Wings..."
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
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

# Fungsi untuk membuat akun admin
create_admin_account() {
    echo "7. Membuat akun admin panel Pterodactyl..."
    echo "Masukkan nama pengguna admin: "
    read ADMIN_USER
    echo "Masukkan email admin: "
    read ADMIN_EMAIL
    echo "Masukkan password admin: "
    read -s ADMIN_PASS

    php /var/www/pterodactyl/artisan p:user:make $ADMIN_USER $ADMIN_EMAIL $ADMIN_PASS --admin
    echo "Akun admin $ADMIN_USER telah dibuat."
}

# Menu utama
while true; do
    clear
    echo "=============================="
    echo "Installer Pterodactyl Panel + Wings"
    echo "=============================="
    echo "Pilih opsi:"
    echo "0. Instal semua (Panel + Wings)"
    echo "1. Instal Pterodactyl Panel saja"
    echo "2. Instal Wings saja"
    echo "3. Keluar"
    echo "=============================="
    read -p "Masukkan pilihan Anda: " choice

    case $choice in
        0)
            install_dependencies
            install_php_composer
            setup_database
            install_panel
            setup_nginx
            install_wings
            create_admin_account  # Menambahkan pembuatan akun admin
            echo "Instalasi selesai!"
            break
            ;;
        1)
            install_dependencies
            install_php_composer
            setup_database
            install_panel
            setup_nginx
            create_admin_account  # Menambahkan pembuatan akun admin
            echo "Panel telah diinstal!"
            break
            ;;
        2)
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
