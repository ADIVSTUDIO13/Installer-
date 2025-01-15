#!/bin/bash

set -e
LOG_FILE="/var/log/pterodactyl-installer.log"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

output() {
  echo -e "\e[1;32m[INFO]\e[0m $1"
  log "$1"
}

error() {
  echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
  log "ERROR: $1"
  exit 1
}

validate_email() {
  if ! [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    error "Email tidak valid. Silakan coba lagi."
  fi
}

validate_domain() {
  if ! [[ "$1" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    error "Domain tidak valid. Silakan coba lagi."
  fi
}

install_dependencies() {
  output "Menginstal dependensi dasar..."
  apt update && apt upgrade -y
  apt install -y curl zip unzip tar wget git nginx mariadb-server software-properties-common ufw \
    build-essential libssl-dev libcurl4-openssl-dev zlib1g-dev
}

install_php_composer() {
  output "Menginstal PHP dan Composer..."
  add-apt-repository -y ppa:ondrej/php
  apt update
  apt install -y php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml php8.1-bcmath php8.1-json php8.1-common php8.1-tokenizer php8.1-zip
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

setup_database() {
  output "Mengatur database untuk Pterodactyl..."
  DB_PASSWORD=$(openssl rand -base64 12)
  mysql -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
  mysql -e "CREATE DATABASE panel;"
  mysql -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
  mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
  mysql -e "FLUSH PRIVILEGES;"
  output "Database berhasil disiapkan dengan password: ${DB_PASSWORD}"
}

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

  # Input nama dan email admin
  echo -n "Masukkan nama admin: "
  read ADMIN_NAME
  echo -n "Masukkan email admin: "
  read ADMIN_EMAIL
  validate_email "$ADMIN_EMAIL"
  echo -n "Masukkan password admin: "
  read -s ADMIN_PASSWORD

  php artisan p:user:make \
    --email="$ADMIN_EMAIL" \
    --username="$ADMIN_NAME" \
    --name="$ADMIN_NAME" \
    --password="$ADMIN_PASSWORD" \
    --admin=1
  output "Admin berhasil dibuat dengan email: $ADMIN_EMAIL"
}

setup_nginx() {
  output "Mengonfigurasi Nginx..."
  echo -n "Masukkan domain utama Anda (tanpa http/https): "
  read DOMAIN
  validate_domain "$DOMAIN"
  echo -n "Masukkan domain untuk node Anda (tanpa http/https): "
  read NODE_DOMAIN
  validate_domain "$NODE_DOMAIN"

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

install_wings() {
  output "Menginstal Wings..."
  mkdir -p /etc/pterodactyl
  cd /etc/pterodactyl
  curl -Lo wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
  chmod u+x wings
}

menu() {
  echo "========================================="
  echo "         Pterodactyl Installer           "
  echo "========================================="
  echo "Apa yang ingin Anda lakukan?"
  echo "[1] Install Panel"
  echo "[2] Install Wings"
  echo "[3] Install Panel dan Wings"
  echo "[4] Keluar"
  echo -n "Pilih opsi (1-4): "
  read choice

  case $choice in
    1)
      install_dependencies
      install_php_composer
      setup_database
      install_panel
      setup_nginx
      ;;
    2)
      install_dependencies
      install_wings
      ;;
    3)
      install_dependencies
      install_php_composer
      setup_database
      install_panel
      setup_nginx
      install_wings
      ;;
    4)
      output "Keluar dari installer."
      exit 0
      ;;
    *)
      error "Pilihan tidak valid, silakan coba lagi."
      menu
      ;;
  esac
}

menu
