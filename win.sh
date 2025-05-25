#!/bin/bash

# Script untuk menginstal Windows dalam Docker container menggunakan dockur/windows
# Berdasarkan: https://github.com/dockur/windows
# Versi tanpa KVM untuk VPS yang tidak mendukung virtualisasi KVM
# Pastikan script ini dijalankan dengan hak akses root (sudo)

# Fungsi untuk memeriksa apakah perintah tersedia
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fungsi untuk menginstal Docker jika belum terinstal
install_docker() {
    if ! command_exists docker; then
        echo "Docker tidak ditemukan. Menginstal Docker..."
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
        systemctl enable docker
    else
        echo "Docker sudah terinstal."
    fi
}

# Fungsi untuk menampilkan menu pemilihan versi Windows
select_windows_version() {
    echo "Pilih versi Windows yang ingin diinstal:"
    echo "1. Windows 11 Pro (default)"
    echo "2. Windows 10 Pro"
    echo "3. Windows Server 2022"
    echo "4. Windows Server 2019"
    echo "5. Masukkan versi kustom (contoh: win10, win11, 2022)"
    read -p "Masukkan pilihan (1-5): " choice

    case $choice in
        1) VERSION="11" ;;
        2) VERSION="10" ;;
        3) VERSION="2022" ;;
        4) VERSION="2019" ;;
        5) read -p "Masukkan versi Windows (contoh: win10, win11, 2022): " VERSION ;;
        *) echo "Pilihan tidak valid, menggunakan Windows 11 Pro sebagai default." ; VERSION="11" ;;
    esac
}

# Fungsi untuk mengatur konfigurasi tambahan
configure_settings() {
    read -p "Masukkan ukuran RAM (default: 4G, contoh: 8G): " RAM_SIZE
    RAM_SIZE=${RAM_SIZE:-4G}
    read -p "Masukkan jumlah CPU cores (default: 2, contoh: 4): " CPU_CORES
    CPU_CORES=${CPU_CORES:-2}
    read -p "Masukkan ukuran disk (default: 64G, contoh: 128G): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-64G}
    read -p "Masukkan bahasa (default: en-US, contoh: fr-FR, de-DE): " LANGUAGE
    LANGUAGE=${LANGUAGE:-en-US}
    read -p "Masukkan nama pengguna (default: Docker): " USERNAME
    USERNAME=${USERNAME:-Docker}
    read -p "Masukkan kata sandi (default: admin): " PASSWORD
    PASSWORD=${PASSWORD:-admin}
}

# Fungsi untuk membuat docker-compose.yml
create_docker_compose() {
    cat > docker-compose.yml <<EOL
version: '3.8'
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "${VERSION}"
      RAM_SIZE: "${RAM_SIZE}"
      CPU_CORES: "${CPU_CORES}"
      DISK_SIZE: "${DISK_SIZE}"
      LANGUAGE: "${LANGUAGE}"
      USERNAME: "${USERNAME}"
      PASSWORD: "${PASSWORD}"
    devices:
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    volumes:
      - ./windows:/storage
    stop_grace_period: 2m
    privileged: true
EOL
}

# Fungsi utama
main() {
    # Pastikan dijalankan sebagai root
    if [ "$EUID" -ne 0 ]; then
        echo "Script ini harus dijalankan sebagai root (gunakan sudo)."
        exit 1
    fi

    echo "Memulai instalasi Windows dalam Docker container..."

    # Instal dependensi
    install_docker

    # Pilih versi Windows
    select_windows_version

    # Konfigurasi pengaturan
    configure_settings

    # Buat file docker-compose.yml
    create_docker_compose

    # Jalankan container
    echo "Memulai container Windows..."
    docker-compose up -d

    echo "Container Windows telah dimulai. Akses melalui browser di http://<IP_VPS>:8006"
    echo "Untuk pengalaman lebih baik, gunakan Microsoft Remote Desktop dengan IP VPS, username: ${USERNAME}, password: ${PASSWORD}"
    echo "Catatan: Instalasi akan berjalan otomatis. Tunggu hingga desktop muncul."
    echo "Jangan lupa untuk memberikan star pada repo: https://github.com/dockur/windows"
}

# Jalankan fungsi utama
main