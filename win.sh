#!/bin/bash

# Script untuk menginstal Docker, Docker Compose, dan menjalankan dockur/windows dengan pilihan versi Windows dan akses VNC

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Fungsi untuk memeriksa apakah perintah tersedia
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Memeriksa dan menginstal Docker jika belum ada
echo "Memeriksa Docker..."
if ! command_exists docker; then
    echo "Docker tidak ditemukan. Menginstal Docker..."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
    echo -e "${GREEN}Docker berhasil diinstal.${NC}"
else
    echo -e "${GREEN}Docker sudah terinstal.${NC}"
fi

# Memeriksa dan menginstal Docker Compose jika belum ada
echo "Memeriksa Docker Compose..."
if ! command_exists docker-compose; then
    echo "Docker Compose tidak ditemukan. Menginstal Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose berhasil diinstal.${NC}"
else
    echo -e "${GREEN}Docker Compose sudah terinstal.${NC}"
fi

# Memeriksa KVM
if ! command_exists kvm-ok; then
    echo "Menginstal cpu-checker untuk memeriksa KVM..."
    sudo apt update && sudo apt install -y cpu-checker
fi

echo "Memeriksa dukungan KVM..."
if ! sudo kvm-ok; then
    echo -e "${RED}KVM tidak didukung atau tidak diaktifkan. Periksa BIOS (Intel VT-x/AMD SVM) atau pastikan Anda tidak menggunakan Docker Desktop untuk Linux.${NC}"
    exit 1
fi

# Meminta pengguna memilih versi Windows
echo "Pilih versi Windows yang ingin diinstal:"
echo "1. Windows 11 Pro"
echo "2. Windows 10 Pro"
echo "3. Windows Server 2022"
echo "4. Masukkan URL ISO khusus (contoh: tiny11)"
read -p "Masukkan nomor pilihan (1-4): " choice

case $choice in
    1)
        VERSION="11"
        ;;
    2)
        VERSION="10"
        ;;
    3)
        VERSION="2022"
        ;;
    4)
        read -p "Masukkan URL ISO khusus: " custom_url
        VERSION="$custom_url"
        ;;
    *)
        echo -e "${RED}Pilihan tidak valid. Menggunakan default: Windows 11 Pro.${NC}"
        VERSION="11"
        ;;
esac

# Membuat direktori untuk storage
echo "Membuat direktori untuk storage..."
mkdir -p ./windows

# Membuat file docker-compose.yml dengan dukungan VNC
echo "Membuat konfigurasi Docker Compose..."
cat > docker-compose.yml << EOL
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "$VERSION"
      VNC_ENABLED: "true"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
      - 5900:5900
    volumes:
      - ./windows:/storage
    restart: always
    stop_grace_period: 2m
EOL

# Menjalankan Docker container
echo "Menjalankan container Windows..."
docker-compose up -d

# Menampilkan instruksi
echo -e "${GREEN}Instalasi selesai!${NC}"
echo "1. Buka browser Anda dan akses http://localhost:8006 untuk melihat proses instalasi."
echo "2. Untuk akses via VNC, gunakan VNC client (contoh: VNC Viewer) ke localhost:5900."
echo "3. Untuk akses via RDP, gunakan port 3389 (contoh: 192.168.0.2:3389)."
echo "4. Tunggu hingga desktop Windows muncul (proses otomatis)."
echo "5. Folder storage ada di $(pwd)/windows."
echo "6. Untuk menghentikan container, jalankan: docker-compose down"
echo -e "${GREEN}Jangan lupa beri bintang di repo: https://github.com/dockur/windows${NC}"

exit 0