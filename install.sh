#!/bin/bash

# Warna
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Tampilan Selamat Datang
display_welcome() {
  clear
  echo -e "${RED}===============================================================${NC}"
  echo -e "${RED}|                                                             |${NC}"
  echo -e "${RED}|                 AUTO INSTALLER PANEL v2                     |${NC}"
  echo -e "${RED}|                    MUDAH BY THOMZ                           |${NC}"
  echo -e "${RED}|                                                             |${NC}"
  echo -e "${RED}===============================================================${NC}"
  echo -e ""
  sleep 4
}

# Cek Token
check_token() {
  clear
  echo -e "${RED}===============================================================${NC}"
  echo -e "${RED}|               CEK TOKEN AUTO INSTALLER                     |${NC}"
  echo -e "${RED}|               DAPATKAN DI CHANNEL ARYASTORE               |${NC}"
  echo -e "${RED}===============================================================${NC}"
  echo -e ""
  echo -ne "${RED}TOKEN : ${NC}"
  read -r USER_TOKEN

  if [ "$USER_TOKEN" = "aryastore12" ]; then
    echo -e "${GREEN}-> TOKEN VALID! Akses diberikan.${NC}"
  else
    echo -e "${RED}-> TOKEN SALAH! Akses ditolak.${NC}"
    exit 1
  fi
  sleep 2
  clear
}

# Instalasi Panel
install_theme() {
  while true; do
    echo -e "${RED}===============================================================${NC}"
    echo -e "${RED}|            APAKAH INGIN MELANJUTKAN INSTALLASI?            |${NC}"
    echo -e "${RED}===============================================================${NC}"
    echo -e "Ingin melanjutkan ke proses penginstalan? (y/n)"
    read -r INSTAL_THOMZ
    case "$INSTAL_THOMZ" in
      y|Y)
        clear
        echo -e "${RED}===============================================================${NC}"
        echo -e "${RED}|                MASUKAN SUBDOMAIN KAMU                      |${NC}"
        echo -e "${RED}|            Contoh: panel.aryastore.site                    |${NC}"
        echo -e "${RED}===============================================================${NC}"
        read -rp "> Subdomain: " Domain

        bash <(curl -s https://raw.githubusercontent.com/rafiadrian1/kuliah/main/autoinstall.sh) "$Domain" true admin@gmail.com thomz ganteng admin thomz true

        echo -e "${GREEN}===============================================================${NC}"
        echo -e "${GREEN}|                   INSTALL SUCCESS                          |${NC}"
        echo -e "${GREEN}===============================================================${NC}"
        sleep 2
        break
        ;;
      n|N)
        return
        ;;
      *)
        echo -e "${RED}Pilihan tidak valid, silahkan coba lagi.${NC}"
        ;;
    esac
  done
}

# Buat Node
create_node() {
  clear
  echo -e "${BLUE}[+]===========================================================[+]${NC}"
  echo -e "${BLUE}[+]                       CREATE NODE                          [+]${NC}"
  echo -e "${BLUE}[+]===========================================================[+]${NC}"
  echo -e ""
  read -rp "Input Domain Yang Sebelumnya: " Domain

  cd /var/www/pterodactyl || { echo "Direktori tidak ditemukan"; exit 1; }

  php artisan p:location:make <<EOF
Thomvelz
Autoinstaller Thomvelz
EOF

  php artisan p:node:make <<EOF
NODE JS
Autoinstaller By Thomz
1
https
$Domain
yes
no
no
160000000
0
160000000
0
100
8080
2022
/var/lib/pterodactyl/volumes
EOF

  echo -e "${GREEN}[+]===========================================================[+]${NC}"
  echo -e "${GREEN}[+]        CREATE NODE & LOCATION SUKSES                      [+]${NC}"
  echo -e "${GREEN}[+]===========================================================[+]${NC}"
  sleep 2
  clear
}

# Main Program
display_welcome
check_token

while true; do
  clear
  echo -e "${RED}===============================================================${NC}"
  echo -e "${RED}|                Project By Thomz @ v2                        |${NC}"
  echo -e "${RED}|       Copyright 2025 | Youtube: aryastore | WA: 6283834510927 |${NC}"
  echo -e "${RED}===============================================================${NC}"
  echo -e ""
  echo -e "PILIH MENU:"
  echo -e "1. Install panel"
  echo -e "2. Create Node"
  echo -e "x. Exit"
  echo -ne "\n> Pilihan Anda: "
  read -r MENU_CHOICE

  case "$MENU_CHOICE" in
    1) install_theme ;;
    2) create_node ;;
    x|X) echo "Keluar dari skrip."; exit 0 ;;
    *) echo -e "${RED}Pilihan tidak valid, silahkan coba lagi.${NC}"; sleep 2 ;;
  esac
done
