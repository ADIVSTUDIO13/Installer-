#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_input() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

if [[ $EUID -eq 0 ]]; then
    log_warning "Script tidak perlu dijalankan sebagai root. Menggunakan user biasa."
fi

N8N_DIR="$HOME/n8n"
COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
ENV_FILE="$N8N_DIR/.env"

configure_firewall() {
    log_info "Konfigurasi firewall untuk port $N8N_PORT"
    
    if command -v ufw >/dev/null 2>&1; then
        if sudo ufw status | grep -q "Status: active"; then
            sudo ufw allow $N8N_PORT/tcp
            log_success "Port $N8N_PORT diizinkan di UFW"
        fi
    fi
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        if sudo firewall-cmd --state >/dev/null 2>&1; then
            sudo firewall-cmd --permanent --add-port=$N8N_PORT/tcp
            sudo firewall-cmd --reload
            log_success "Port $N8N_PORT diizinkan di firewalld"
        fi
    fi
    
    if command -v iptables >/dev/null 2>&1; then
        if ! sudo iptables -L INPUT | grep -q "tcp dpt:$N8N_PORT"; then
            sudo iptables -A INPUT -p tcp --dport $N8N_PORT -j ACCEPT
            log_success "Port $N8N_PORT diizinkan di iptables"
        fi
    fi
}

open_ports() {
    log_info "Membuka port yang diperlukan"
    
    PORTS=("443" "80" "5678" "$N8N_PORT")
    
    for port in "${PORTS[@]}"; do
        if command -v ufw >/dev/null 2>&1; then
            if sudo ufw status | grep -q "Status: active"; then
                if ! sudo ufw status | grep -q "$port/tcp"; then
                    sudo ufw allow $port/tcp
                    log_success "UFW: Port $port diizinkan"
                fi
            fi
        fi
        
        if command -v firewall-cmd >/dev/null 2>&1; then
            if sudo firewall-cmd --state >/dev/null 2>&1; then
                if ! sudo firewall-cmd --list-ports | grep -q "$port/tcp"; then
                    sudo firewall-cmd --permanent --add-port=$port/tcp
                    log_success "Firewalld: Port $port diizinkan"
                fi
            fi
        fi
    done
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --reload
    fi
}

get_user_input() {
    echo ""
    log_info "KONFIGURASI n8n"
    
    while true; do
        log_input "Masukkan domain/webhook URL untuk n8n:"
        read -p "Webhook URL: " WEBHOOK_URL
        
        if [[ -z "$WEBHOOK_URL" ]]; then
            log_error "Webhook URL tidak boleh kosong!"
            continue
        fi
        
        if [[ $WEBHOOK_URL =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
            break
        else
            log_error "Format URL tidak valid! Gunakan format: http(s)://domain:port"
        fi
    done
    
    if [[ $WEBHOOK_URL =~ ^(https?://)([^:/]+)(:([0-9]+))? ]]; then
        N8N_PROTOCOL="${BASH_REMATCH[1]%://}"
        N8N_HOST="${BASH_REMATCH[2]}"
        N8N_PORT="${BASH_REMATCH[4]:-5678}"
    else
        N8N_PROTOCOL="http"
        N8N_HOST="localhost"
        N8N_PORT="5678"
    fi
    
    echo ""
    log_input "Aktifkan Basic Authentication? (y/n):"
    read -p "Basic Auth [y/N]: " ENABLE_BASIC_AUTH
    ENABLE_BASIC_AUTH=${ENABLE_BASIC_AUTH:-n}
    
    if [[ $ENABLE_BASIC_AUTH =~ ^[Yy]$ ]]; then
        BASIC_AUTH_ACTIVE="true"
        log_input "Masukkan username untuk Basic Auth:"
        read -p "Username [n8n]: " BASIC_AUTH_USER
        BASIC_AUTH_USER=${BASIC_AUTH_USER:-n8n}
        
        while true; do
            log_input "Masukkan password untuk Basic Auth:"
            read -s -p "Password: " BASIC_AUTH_PASSWORD
            echo
            if [[ -z "$BASIC_AUTH_PASSWORD" ]]; then
                log_error "Password tidak boleh kosong!"
                continue
            fi
            log_input "Konfirmasi password:"
            read -s -p "Confirm Password: " BASIC_AUTH_PASSWORD_CONFIRM
            echo
            if [[ "$BASIC_AUTH_PASSWORD" != "$BASIC_AUTH_PASSWORD_CONFIRM" ]]; then
                log_error "Password tidak cocok!"
            else
                break
            fi
        done
    else
        BASIC_AUTH_ACTIVE="false"
        BASIC_AUTH_USER="user"
        BASIC_AUTH_PASSWORD="password"
        log_warning "Basic Auth dinonaktifkan - Tidak aman untuk production!"
    fi
    
    echo ""
    log_input "Masukkan timezone:"
    read -p "Timezone [Asia/Jakarta]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-Asia/Jakarta}
    
    echo ""
    log_input "Masukkan password untuk database PostgreSQL:"
    read -s -p "DB Password [n8n_password]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-n8n_password}
    echo
    
    echo ""
    log_input "Buka port di firewall otomatis? (y/n):"
    read -p "Open ports [Y/n]: " OPEN_PORTS
    OPEN_PORTS=${OPEN_PORTS:-y}
    
    echo ""
    log_info "SUMMARY KONFIGURASI"
    log_success "Webhook URL: $WEBHOOK_URL"
    log_success "Protocol: $N8N_PROTOCOL"
    log_success "Host: $N8N_HOST"
    log_success "Port: $N8N_PORT"
    log_success "Basic Auth: $BASIC_AUTH_ACTIVE"
    if [[ $BASIC_AUTH_ACTIVE == "true" ]]; then
        log_success "Username: $BASIC_AUTH_USER"
        log_success "Password: ********"
    fi
    log_success "Timezone: $TIMEZONE"
    log_success "DB Password: ********"
    log_success "Open Ports: $OPEN_PORTS"
    echo ""
    
    log_input "Konfigurasi sudah benar? (y/n):"
    read -p "Lanjutkan? [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        log_info "Mengulang konfigurasi..."
        get_user_input
    fi
}

check_docker() {
    log_info "Memeriksa instalasi Docker..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker tidak terinstall. Menginstall Docker..."
        install_docker
    else
        log_success "Docker sudah terinstall"
    fi

    log_info "Memeriksa Docker Compose..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose tidak terinstall. Menginstall Docker Compose..."
        install_docker_compose
    else
        log_success "Docker Compose sudah terinstall"
    fi
}

install_docker() {
    log_info "Menginstall Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker berhasil diinstall"
    log_warning "Silakan logout dan login kembali untuk apply group docker"
}

install_docker_compose() {
    log_info "Menginstall Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose berhasil diinstall"
}

create_directory() {
    log_info "Membuat direktori n8n..."
    mkdir -p $N8N_DIR
    log_success "Direktori n8n dibuat: $N8N_DIR"
}

create_env_file() {
    log_info "Membuat file environment..."
    
    cat > $ENV_FILE << EOF
N8N_VERSION=latest
N8N_BASIC_AUTH_ACTIVE=${BASIC_AUTH_ACTIVE}
N8N_BASIC_AUTH_USER=${BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${BASIC_AUTH_PASSWORD}
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_HOST=${N8N_HOST}
N8N_PORT=${N8N_PORT}
N8N_WEBHOOK_URL=${WEBHOOK_URL}/
DB_HOST=postgres
DB_PORT=5432
DB_NAME=n8n
DB_USER=n8n
DB_PASSWORD=${DB_PASSWORD}
GENERIC_TIMEZONE=${TIMEZONE}
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
EOF

    log_success "File environment dibuat: $ENV_FILE"
}

create_docker_compose() {
    log_info "Membuat docker-compose.yml..."
    
    cat > $COMPOSE_FILE << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "${N8N_PORT}:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${DB_NAME}
      - DB_POSTGRESDB_USER=\${DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${DB_PASSWORD}
      - N8N_BASIC_AUTH_ACTIVE=\${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=\${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=\${N8N_BASIC_AUTH_PASSWORD}
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - N8N_PROTOCOL=\${N8N_PROTOCOL}
      - N8N_HOST=\${N8N_HOST}
      - N8N_PORT=\${N8N_PORT}
      - N8N_WEBHOOK_URL=\${N8N_WEBHOOK_URL}
      - GENERIC_TIMEZONE=\${GENERIC_TIMEZONE}
      - N8N_DIAGNOSTICS_ENABLED=\${N8N_DIAGNOSTICS_ENABLED}
      - N8N_PERSONALIZATION_ENABLED=\${N8N_PERSONALIZATION_ENABLED}
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
    restart: unless-stopped
    networks:
      - n8n_network

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=\${DB_NAME}
      - POSTGRES_USER=\${DB_USER}
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - n8n_network

volumes:
  n8n_data:
  postgres_data:

networks:
  n8n_network:
    driver: bridge
EOF

    log_success "Docker compose file dibuat: $COMPOSE_FILE"
}

generate_encryption_key() {
    log_info "Generate encryption key..."
    if command -v openssl &> /dev/null; then
        ENCRYPTION_KEY=$(openssl rand -base64 24)
        log_success "Encryption key telah digenerate secara otomatis"
    else
        ENCRYPTION_KEY="manual-encryption-key-please-change-in-env-file"
        log_warning "openssl tidak tersedia, menggunakan encryption key default"
    fi
}

start_n8n() {
    log_info "Starting n8n services..."
    cd $N8N_DIR
    
    if [[ $OPEN_PORTS =~ ^[Yy]$ ]]; then
        open_ports
        configure_firewall
    fi
    
    if docker-compose ps | grep -q "Up"; then
        log_warning "Services sudah berjalan, restarting..."
        docker-compose down
    fi
    
    docker-compose up -d
    
    log_info "Menunggu services mulai..."
    for i in {1..30}; do
        if curl -s http://localhost:${N8N_PORT} > /dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    log_success "n8n berhasil diinstall dan dijalankan!"
}

show_status() {
    log_info "Memeriksa status services..."
    cd $N8N_DIR
    docker-compose ps
    
    log_info "n8n accessible at: $WEBHOOK_URL"
    
    if [[ $BASIC_AUTH_ACTIVE == "true" ]]; then
        log_info "Username: $BASIC_AUTH_USER"
        log_info "Password: ********"
    fi
}

get_uninstall_input() {
    echo ""
    log_warning "=== UNINSTALL n8n ==="
    log_warning "Tindakan ini akan menghapus SEMUA DATA n8n termasuk:"
    log_warning "✓ Workflows"
    log_warning "✓ Credentials" 
    log_warning "✓ Database PostgreSQL"
    log_warning "✓ Konfigurasi"
    log_warning "✓ Semua file n8n"
    echo ""
    
    log_input "Apakah Anda yakin ingin melanjutkan uninstall? (y/n):"
    read -p "Konfirmasi [y/N]: " CONFIRM_UNINSTALL
    CONFIRM_UNINSTALL=${CONFIRM_UNINSTALL:-n}
    
    if [[ ! $CONFIRM_UNINSTALL =~ ^[Yy]$ ]]; then
        log_info "Uninstall dibatalkan"
        exit 0
    fi
    
    echo ""
    log_input "Hapus juga Docker volumes (data permanen terhapus)? (y/n):"
    read -p "Hapus volumes [Y/n]: " DELETE_VOLUMES
    DELETE_VOLUMES=${DELETE_VOLUMES:-y}
    
    echo ""
    log_input "Hapus juga direktori n8n ($N8N_DIR)? (y/n):"
    read -p "Hapus direktori [Y/n]: " DELETE_DIR
    DELETE_DIR=${DELETE_DIR:-y}
    
    echo ""
    log_input "Tutup port firewall yang dibuka? (y/n):"
    read -p "Tutup port [Y/n]: " CLOSE_PORTS
    CLOSE_PORTS=${CLOSE_PORTS:-y}
    
    echo ""
    log_warning "SUMMARY UNINSTALL:"
    log_warning "Hapus volumes: $DELETE_VOLUMES"
    log_warning "Hapus direktori: $DELETE_DIR"
    log_warning "Tutup port: $CLOSE_PORTS"
    echo ""
    
    log_input "Lanjutkan uninstall? (y/n):"
    read -p "Uninstall sekarang? [y/N]: " FINAL_CONFIRM
    FINAL_CONFIRM=${FINAL_CONFIRM:-n}
    
    if [[ ! $FINAL_CONFIRM =~ ^[Yy]$ ]]; then
        log_info "Uninstall dibatalkan"
        exit 0
    fi
}

close_ports() {
    log_info "Menutup port firewall..."
    
    if [[ -f "$ENV_FILE" ]]; then
        source $ENV_FILE
    fi
    
    PORTS=("443" "80" "5678" "${N8N_PORT:-5678}")
    
    for port in "${PORTS[@]}"; do
        if command -v ufw >/dev/null 2>&1; then
            if sudo ufw status | grep -q "Status: active"; then
                if sudo ufw status | grep -q "$port/tcp"; then
                    sudo ufw delete allow $port/tcp
                    log_success "UFW: Port $port ditutup"
                fi
            fi
        fi
        
        if command -v firewall-cmd >/dev/null 2>&1; then
            if sudo firewall-cmd --state >/dev/null 2>&1; then
                if sudo firewall-cmd --list-ports | grep -q "$port/tcp"; then
                    sudo firewall-cmd --permanent --remove-port=$port/tcp
                    log_success "Firewalld: Port $port ditutup"
                fi
            fi
        fi
    done
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --reload
    fi
}

uninstall_n8n() {
    get_uninstall_input
    
    log_info "Memulai proses uninstall n8n..."
    
    if [[ -d "$N8N_DIR" ]]; then
        cd $N8N_DIR
        
        log_info "Menghentikan services..."
        docker-compose down
        
        if [[ $DELETE_VOLUMES =~ ^[Yy]$ ]]; then
            log_info "Menghapus Docker volumes..."
            docker-compose down -v
            docker volume rm n8n_n8n_data n8n_postgres_data 2>/dev/null || true
            docker volume rm $(docker volume ls -q | grep n8n) 2>/dev/null || true
            log_success "Docker volumes dihapus"
        else
            log_info "Menyimpan Docker volumes"
        fi
        
        if [[ $CLOSE_PORTS =~ ^[Yy]$ ]]; then
            close_ports
        fi
        
        if [[ $DELETE_DIR =~ ^[Yy]$ ]]; then
            log_info "Menghapus direktori n8n..."
            cd $HOME
            rm -rf $N8N_DIR
            log_success "Direktori n8n dihapus: $N8N_DIR"
        else
            log_info "Menyimpan direktori n8n: $N8N_DIR"
        fi
        
        log_success "n8n berhasil diuninstall"
        
        echo ""
        log_info "RINGKASAN UNINSTALL:"
        if [[ $DELETE_VOLUMES =~ ^[Yy]$ ]]; then
            log_warning "✓ Semua data n8n dihapus permanen"
        else
            log_info "✓ Data n8n disimpan di Docker volumes"
        fi
        if [[ $DELETE_DIR =~ ^[Yy]$ ]]; then
            log_warning "✓ Direktori konfigurasi dihapus"
        else
            log_info "✓ Direktori konfigurasi disimpan"
        fi
        if [[ $CLOSE_PORTS =~ ^[Yy]$ ]]; then
            log_info "✓ Port firewall ditutup"
        else
            log_info "✓ Port firewall tetap terbuka"
        fi
        
    else
        log_error "Direktori n8n tidak ditemukan: $N8N_DIR"
        log_info "Membersihkan sisa-sisa instalasi..."
        
        docker-compose -f $COMPOSE_FILE down 2>/dev/null || true
        docker-compose -f $COMPOSE_FILE down -v 2>/dev/null || true
        
        if [[ $CLOSE_PORTS =~ ^[Yy]$ ]]; then
            close_ports
        fi
        
        log_success "Pembersihan selesai"
    fi
}

main() {
    log_info "Memulai instalasi n8n..."
    
    get_user_input
    check_docker
    create_directory
    generate_encryption_key
    create_env_file
    create_docker_compose
    start_n8n
    
    echo ""
    log_success "n8n BERHASIL DIINSTALL"
    log_info "Akses n8n di: $WEBHOOK_URL"
    if [[ $BASIC_AUTH_ACTIVE == "true" ]]; then
        log_info "Username: $BASIC_AUTH_USER"
        log_info "Password: Password yang Anda masukkan"
    fi
    log_info "Direktori n8n: $N8N_DIR"
    log_info "File konfigurasi: $ENV_FILE"
    log_info "Port: $N8N_PORT"
    echo ""
    log_info "Perintah manajemen:"
    log_info "  ./installer.sh status    - Lihat status"
    log_info "  ./installer.sh stop      - Hentikan n8n"
    log_info "  ./installer.sh start     - Jalankan n8n"
    log_info "  ./installer.sh restart   - Restart n8n"
    log_info "  ./installer.sh update    - Update n8n"
    log_info "  ./installer.sh uninstall - Hapus n8n"
}

cmd_status() {
    if [[ ! -d "$N8N_DIR" ]]; then
        log_error "n8n belum diinstall. Jalankan: ./installer.sh"
        exit 1
    fi
    cd $N8N_DIR
    show_status
}

cmd_stop() {
    if [[ ! -d "$N8N_DIR" ]]; then
        log_error "n8n belum diinstall. Jalankan: ./installer.sh"
        exit 1
    fi
    log_info "Menghentikan n8n..."
    cd $N8N_DIR
    docker-compose down
    log_success "n8n dihentikan"
}

cmd_start() {
    if [[ ! -d "$N8N_DIR" ]]; then
        log_error "n8n belum diinstall. Jalankan: ./installer.sh"
        exit 1
    fi
    log_info "Menjalankan n8n..."
    cd $N8N_DIR
    docker-compose up -d
    log_success "n8n dijalankan"
}

cmd_restart() {
    if [[ ! -d "$N8N_DIR" ]]; then
        log_error "n8n belum diinstall. Jalankan: ./installer.sh"
        exit 1
    fi
    log_info "Restart n8n..."
    cd $N8N_DIR
    docker-compose restart
    log_success "n8n di-restart"
}

cmd_update() {
    if [[ ! -d "$N8N_DIR" ]]; then
        log_error "n8n belum diinstall. Jalankan: ./installer.sh"
        exit 1
    fi
    log_info "Update n8n..."
    cd $N8N_DIR
    docker-compose pull
    docker-compose up -d
    log_success "n8n di-update"
}

case "${1:-}" in
    status)
        cmd_status
        ;;
    stop)
        cmd_stop
        ;;
    start)
        cmd_start
        ;;
    restart)
        cmd_restart
        ;;
    update)
        cmd_update
        ;;
    uninstall)
        uninstall_n8n
        ;;
    help|--help|-h)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install   - Install n8n (default)"
        echo "  status    - Show status"
        echo "  start     - Start n8n"
        echo "  stop      - Stop n8n"
        echo "  restart   - Restart n8n"
        echo "  update    - Update n8n"
        echo "  uninstall - Uninstall n8n dan hapus semua data"
        echo "  help      - Show this help"
        echo ""
        ;;
    *)
        main
        ;;
esac