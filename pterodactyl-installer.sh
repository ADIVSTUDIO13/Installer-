#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'Custom Pterodactyl Installer'                                             #
#                                                                                    #
# Author: Your Name                                                                  #
#                                                                                    #
# This script is free software under the GNU GPL v3 license.                         #
#                                                                                    #
# This script helps to install Pterodactyl Panel and/or Wings on your server.        #
#                                                                                    #
######################################################################################

LOG_PATH="/var/log/custom-pterodactyl-installer.log"

# Fungsi umum untuk output
output() {
  echo -e "\e[1;32m[INFO]\e[0m $1"
}

warning() {
  echo -e "\e[1;33m[WARNING]\e[0m $1"
}

error() {
  echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
  exit 1
}

separator() {
  echo "--------------------------------------------------------------------------------"
}

# Fungsi untuk instalasi dependensi dasar
install_dependencies() {
  output "Menginstal dependensi dasar..."
  apt update && apt upgrade -y
  apt install -y curl zip unzip tar wget git nginx mariadb-server software-properties-common ufw \
    build-essential libssl-dev libcurl4-openssl-dev zlib1g-dev
}

# Fungsi untuk menginstal PHP dan Composer
install_php_composer() {
  output "Menginstal PHP dan Composer..."
  add-apt-repository -y ppa:ondrej/php
  apt update
  apt install -y php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-bcmath php8.1-json php8.1-common php8.1-tokenizer php8.1-zip
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

# Fungsi untuk mengatur database
setup_database() {
  output "Mengatur database untuk Pterodactyl..."
  DB_PASSWORD=$(openssl rand -base64 12)
  mysql -e "CREATE DATABASE panel;"
  mysql -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
  mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
  mysql -e "FLUSH PRIVILEGES;"
  separator
  echo -e "\e[1;34mInformasi Database:\e[0m"
  echo "Nama Database: panel"
  echo "User: pterodactyl"
  echo "Password: ${DB_PASSWORD}"
  separator
}

# Fungsi untuk instalasi Panel
install_panel() {
  output "Menginstal Pterodactyl Panel..."
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

# Fungsi untuk mengatur Nginx
setup_nginx() {
  output "Mengonfigurasi Nginx..."
  echo -n "Masukkan domain utama Anda (tanpa http/https): "
  read DOMAIN
  echo -n "Masukkan domain untuk node Anda (tanpa http/https): "
  read NODE_DOMAIN

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
    }

    server {
        listen 80;
        server_name $NODE_DOMAIN;

        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }" > /etc/nginx/sites-available/pterodactyl

  ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
  nginx -t && systemctl restart nginx
  ufw allow 'Nginx Full'
}

# Fungsi untuk instalasi Wings
install_wings() {
  output "Menginstal Wings..."
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

# Menu utama
done=false
while [ "$done" == false ]; do
  options=(
    "Install Panel"
    "Install Wings"
    "Install Panel dan Wings"
    "Keluar"
  )

  actions=(
    "install_dependencies;install_php_composer;setup_database;install_panel;setup_nginx"
    "install_dependencies;install_wings"
    "install_dependencies;install_php_composer;setup_database;install_panel;setup_nginx;install_wings"
    "exit"
  )

  output "Apa yang ingin Anda lakukan?"

  for i in "${!options[@]}"; do
    echo -e "\e[1;33m[$i]\e[0m ${options[$i]}"
  done

  echo -n "Pilih opsi (0-$((${#actions[@]} - 1))): "
  read -r action

  [ -z "$action" ] && error "Input tidak boleh kosong." && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Pilihan tidak valid." && continue

  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && $i1 && [[ -n $i2 ]] && $i2
done

output "Terima kasih telah menggunakan Custom Pterodactyl Installer!"
