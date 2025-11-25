#!/bin/bash

# n8n Auto Installer Script
# Script untuk install n8n otomatis dengan Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if script is run as root
if [[ $EUID -eq 0 ]]; then
    log_warning "Script tidak perlu dijalankan sebagai root. Menggunakan user biasa."
fi

# Variables
N8N_DIR="$HOME/n8n"
COMPOSE_FILE="$N8N_DIR/docker-compose.yml"
ENV_FILE="$N8N_DIR/.env"

# Function to get user input
get_user_input() {
    echo ""
    log_info "=== KONFIGURASI n8n ==="
    log_warning "Untuk production, pastikan domain/webhook URL sudah benar!"
    echo ""
    
    # Get webhook domain
    while true; do
        log_input "Masukkan domain/webhook URL untuk n8n (contoh: https://n8n.domain.com atau http://localhost:5678):"
        read -p "Webhook URL: " WEBHOOK_URL
        
        if [[ -z "$WEBHOOK_URL" ]]; then
            log_error "Webhook URL tidak boleh kosong!"
            continue
        fi
        
        # Validate URL format
        if [[ $WEBHOOK_URL =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
            break
        else
            log_error "Format URL tidak valid! Gunakan format: http(s)://domain:port"
            log_info "Contoh: https://n8n.example.com atau http://localhost:5678"
        fi
    done
    
    # Extract protocol, host, and port from URL
    if [[ $WEBHOOK_URL =~ ^(https?://)([^:/]+)(:([0-9]+))? ]]; then
        N8N_PROTOCOL="${BASH_REMATCH[1]%://}"
        N8N_HOST="${BASH_REMATCH[2]}"
        N8N_PORT="${BASH_REMATCH[4]:-5678}"
    else
        N8N_PROTOCOL="http"
        N8N_HOST="localhost"
        N8N_PORT="5678"
    fi
    
    # Ask for basic auth
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
    
    # Ask for timezone
    echo ""
    log_input "Masukkan timezone (contoh: Asia/Jakarta, Europe/Berlin, America/New_York):"
    read -p "Timezone [Asia/Jakarta]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-Asia/Jakarta}
    
    # Ask for database password
    echo ""
    log_input "Masukkan password untuk database PostgreSQL:"
    read -s -p "DB Password [n8n_password]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-n8n_password}
    echo
    
    # Show configuration summary
    echo ""
    log_info "=== SUMMARY KONFIGURASI ==="
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
    echo ""
    
    log_input "Konfigurasi sudah benar? (y/n):"
    read -p "Lanjutkan? [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        log_info "Mengulang konfigurasi..."
        get_user_input
    fi
}

# Check if Docker is installed
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

# Install Docker
install_docker() {
    log_info "Menginstall Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker berhasil diinstall"
    log_warning "Silakan logout dan login kembali untuk apply group docker, atau jalankan: newgrp docker"
}

# Install Docker Compose
install_docker_compose() {
    log_info "Menginstall Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose berhasil diinstall"
}

# Create n8n directory
create_directory() {
    log_info "Membuat direktori n8n..."
    mkdir -p $N8N_DIR
    log_success "Direktori n8n dibuat: $N8N_DIR"
}

# Create environment file with user configuration
create_env_file() {
    log_info "Membuat file environment..."
    
    cat > $ENV_FILE << EOF
# n8n Configuration
N8N_VERSION=latest

# Basic Auth
N8N_BASIC_AUTH_ACTIVE=${BASIC_AUTH_ACTIVE}
N8N_BASIC_AUTH_USER=${BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${BASIC_AUTH_PASSWORD}

# Encryption Key
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Webhook URL
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_HOST=${N8N_HOST}
N8N_PORT=${N8N_PORT}
N8N_WEBHOOK_URL=${WEBHOOK_URL}/

# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=n8n
DB_USER=n8n
DB_PASSWORD=${DB_PASSWORD}

# Timezone and Security
GENERIC_TIMEZONE=${TIMEZONE}
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false

# Optional: Email Configuration (untuk notifikasi)
# N8N_EMAIL_MODE=smtp
# N8N_SMTP_HOST=smtp.example.com
# N8N_SMTP_PORT=587
# N8N_SMTP_USER=your-email@example.com
# N8N_SMTP_PASS=your-password
# N8N_SMTP_SENDER=your-email@example.com

# Optional: External Database (jika menggunakan database eksternal)
# DATABASE_URL=postgres://username:password@host:port/database
EOF

    log_success "File environment dibuat: $ENV_FILE"
}

# Create docker-compose file
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`${N8N_HOST}\`)"

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

# Generate encryption key
generate_encryption_key() {
    log_info "Generate encryption key..."
    if command -v openssl &> /dev/null; then
        ENCRYPTION_KEY=$(openssl rand -base64 24)
        log_success "Encryption key telah digenerate secara otomatis"
    else
        ENCRYPTION_KEY="manual-encryption-key-please-change-in-env-file"
        log_warning "openssl tidak tersedia, menggunakan encryption key default"
        log_warning "GANTI encryption key di $ENV_FILE untuk production!"
    fi
}

# Start n8n
start_n8n() {
    log_info "Starting n8n services..."
    cd $N8N_DIR
    
    # Check if services are already running
    if docker-compose ps | grep -q "Up"; then
        log_warning "Services sudah berjalan, restarting..."
        docker-compose down
    fi
    
    docker-compose up -d
    
    # Wait for services to start
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

# Show status
show_status() {
    log_info "Memeriksa status services..."
    cd $N8N_DIR
    docker-compose ps
    
    log_info "n8n accessible at: $WEBHOOK_URL"
    
    if [[ $BASIC_AUTH_ACTIVE == "true" ]]; then
        log_info "Username: $BASIC_AUTH_USER"
        log_info "Password: ********"
    fi
    
    log_info "Log n8n (Ctrl+C untuk keluar):"
    docker-compose logs -f n8n
}

# Main installation function
main() {
    log_info "Memulai instalasi n8n..."
    
    # Get user configuration
    get_user_input
    
    check_docker
    create_directory
    generate_encryption_key
    create_env_file
    create_docker_compose
    start_n8n
    
    # Display final information
    echo ""
    log_success "=== n8n BERHASIL DIINSTALL ==="
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
    log_info "  ./installer.sh status  - Lihat status dan logs"
    log_info "  ./installer.sh stop    - Hentikan n8n"
    log_info "  ./installer.sh start   - Jalankan n8n"
    log_info "  ./installer.sh restart - Restart n8n"
    log_info "  ./installer.sh update  - Update n8n"
    echo ""
    log_warning "PENTING UNTUK PRODUCTION:"
    log_warning "1. Edit $ENV_FILE jika perlu perubahan konfigurasi"
    log_warning "2. Pastikan encryption key sudah kuat"
    log_warning "3. Setup reverse proxy dan SSL jika menggunakan domain"
    log_warning "4. Backup volume data secara berkala"
}

# Command functions
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

# Parse command line arguments
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
    help|--help|-h)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install  - Install n8n (default)"
        echo "  status   - Show status and logs"
        echo "  start    - Start n8n"
        echo "  stop     - Stop n8n"
        echo "  restart  - Restart n8n"
        echo "  update   - Update n8n to latest version"
        echo "  help     - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0          # Install n8n"
        echo "  $0 status   # Check status"
        echo "  $0 update   # Update n8n"
        ;;
    *)
        main
        ;;
esac