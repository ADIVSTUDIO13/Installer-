#!/bin/bash

# === Konfigurasi ===
TELEGRAM_TOKEN="7841123826:AAEt8mK6lAG-z_Iys4fM92nZsuMHCd-IRI4"
TELEGRAM_CHAT_ID="5754506310"
KIRIM_TELEGRAM=true
WEB_PANEL_PORT=3000
WEB_PANEL_ENABLE=true

LOGDIR="/var/log/monitor-speed"
mkdir -p "$LOGDIR"

LOGFILE="$LOGDIR/monitor_$(date +%Y-%m-%d_%H-%M-%S).log"

# === Warna CLI ===
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'

print() { echo -e "$1" | tee -a "$LOGFILE"; }
hr() { print "${BLUE}------------------------------------------------------------${NC}"; }
section() { hr; print "${YELLOW}$1${NC}"; hr; }

# === Install dependencies jika belum ada ===
deps=(curl jq lscpu ip speedtest-cli dig dmidecode ss top df free nc)
for tool in "${deps[@]}"; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${YELLOW}Installing $tool...${NC}"
        apt install -y $tool 2>/dev/null || yum install -y $tool 2>/dev/null
    fi
done

# === Install Node.js jika belum ada ===
if [ "$WEB_PANEL_ENABLE" = true ] && ! command -v node &> /dev/null; then
    section "📦 INSTALL NODE.JS"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    npm install -g npm
    print "${GREEN}Node.js installed successfully${NC}"
fi

clear

section "🧠 INFO SISTEM"
print "Tanggal        : $(date)"
print "Hostname       : $(hostname)"
print "OS             : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \")"
print "Kernel         : $(uname -r)"
print "Uptime         : $(uptime -p)"
print "Load Average   : $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
print "Virtualisasi   : $(systemd-detect-virt)"
print "CPU            : $(lscpu | grep 'Model name' | cut -d ':' -f2 | xargs)"
print "Total RAM      : $(free -h | awk '/Mem:/ {print $2}')"

section "🌍 INFO IP PUBLIK & LOKASI"
IP=$(curl -s ifconfig.me)
LOC=$(curl -s ipinfo.io/$IP/json | jq -r '.city, .region, .country' | paste -sd ', ')
print "IP Publik      : $IP"
print "Lokasi Server  : $LOC"

section "🌐 TES KECEPATAN INTERNET"
speedtest-cli --simple | tee -a "$LOGFILE"

section "📶 PING SERVER PENTING"
for host in google.com cloudflare.com openai.com github.com; do
    print "\nPing ke $host:"
    ping -c 3 $host | tail -2 | tee -a "$LOGFILE"
done

section "🔎 TES DNS"
print "Google DNS:"
dig @8.8.8.8 google.com +stats | grep 'Query time' | tee -a "$LOGFILE"
print "\nCloudflare DNS:"
dig @1.1.1.1 openai.com +stats | grep 'Query time' | tee -a "$LOGFILE"

section "📤 HTTP STATUS SITUS"
for site in https://google.com https://cloudflare.com https://openai.com; do
    CODE=$(curl -o /dev/null -s -w "%{http_code}" "$site")
    print "$site : HTTP $CODE"
done

section "🚀 TES RAM"
TMPFILE=$(mktemp)
dd if=/dev/zero of=$TMPFILE bs=1M count=1024 conv=fdatasync status=none
sync
dd if=$TMPFILE of=/dev/null bs=1M status=none | tee -a "$LOGFILE"
rm -f $TMPFILE

section "💾 TES DISK WRITE"
dd if=/dev/zero of=disk_speed_test bs=1G count=1 oflag=dsync 2>&1 | tee -a "$LOGFILE"
rm -f disk_speed_test

section "📊 INFO STORAGE & RAM"
df -hT | tee -a "$LOGFILE"
free -h | tee -a "$LOGFILE"

section "📡 JARINGAN & INTERFACE"
ip -brief address | tee -a "$LOGFILE"
print "\nKoneksi Aktif:"
ss -tuna | head -n 10 | tee -a "$LOGFILE"

section "🛡️ DETEKSI IP ASING MASUK"
ss -tn state established '( sport != :22 )' | grep -v 127.0.0.1 | tee -a "$LOGFILE"

section "🔐 CEK PORT TERBUKA"
for port in 22 80 443 3306; do
    nc -zv 127.0.0.1 $port &>> $LOGFILE && print "Port $port: OPEN" || print "Port $port: CLOSED"
done

section "📦 PAKET UPDATE (APT/YUM)"
if command -v apt &> /dev/null; then
    apt update -qq && apt list --upgradable 2>/dev/null | tee -a "$LOGFILE"
elif command -v yum &> /dev/null; then
    yum check-update | tee -a "$LOGFILE"
fi

section "🌐 SETUP WEB PANEL"
if [ "$WEB_PANEL_ENABLE" = true ]; then
    WEB_PANEL_DIR="/opt/server-monitor"
    mkdir -p "$WEB_PANEL_DIR"
    
    # Create package.json
    cat > "$WEB_PANEL_DIR/package.json" <<EOL
{
  "name": "server-monitor",
  "version": "1.0.0",
  "description": "Server Monitoring Dashboard",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "fs-extra": "^11.1.1",
    "moment": "^2.29.4",
    "socket.io": "^4.7.2"
  }
}
EOL

    # Create server.js with FIXED template literals
    cat > "$WEB_PANEL_DIR/server.js" <<'EOL'
const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const moment = require('moment');
const app = express();
const http = require('http').createServer(app);
const io = require('socket.io')(http);

const LOGDIR = '/var/log/monitor-speed';

app.use(express.static('public'));
app.use(express.json());

// Serve dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API to get logs
app.get('/api/logs', async (req, res) => {
    try {
        const files = await fs.readdir(LOGDIR);
        const sortedFiles = files
            .map(file => ({
                name: file,
                time: fs.statSync(path.join(LOGDIR, file)).mtime.getTime()
            }))
            .sort((a, b) => b.time - a.time)
            .map(file => file.name);

        res.json(sortedFiles);
    } catch (err) {
        res.status(500).send('Error reading log directory');
    }
});

// API to get log content
app.get('/api/log/:filename', async (req, res) => {
    try {
        const filePath = path.join(LOGDIR, req.params.filename);
        const content = await fs.readFile(filePath, 'utf8');
        res.send(content);
    } catch (err) {
        res.status(404).send('Log file not found');
    }
});

// Create public directory and files
async function setupPublic() {
    const publicDir = path.join(__dirname, 'public');
    await fs.ensureDir(publicDir);

    // Create index.html
    const indexHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Monitor Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .log-content {
            background-color: #f8f9fa;
            border-radius: 5px;
            padding: 15px;
            font-family: monospace;
            white-space: pre-wrap;
            height: 500px;
            overflow-y: auto;
        }
        .card {
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container mt-4">
        <h1 class="text-center mb-4">Server Monitoring Dashboard</h1>
        
        <div class="row">
            <div class="col-md-8">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title">Log Content</h5>
                    </div>
                    <div class="card-body">
                        <div id="log-content" class="log-content">Select a log file from the right panel...</div>
                    </div>
                </div>
            </div>
            
            <div class="col-md-4">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title">Log Files</h5>
                    </div>
                    <div class="card-body">
                        <div class="list-group" id="log-files">
                            <div class="text-center">Loading logs...</div>
                        </div>
                    </div>
                </div>
                
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title">Server Info</h5>
                    </div>
                    <div class="card-body">
                        <ul class="list-group" id="server-info">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                Hostname
                                <span class="badge bg-primary rounded-pill" id="hostname">-</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                IP Address
                                <span class="badge bg-primary rounded-pill" id="ip">-</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                Uptime
                                <span class="badge bg-primary rounded-pill" id="uptime">-</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                Load Average
                                <span class="badge bg-primary rounded-pill" id="loadavg">-</span>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/socket.io-client@4.7.2/dist/socket.io.min.js"></script>
    <script>
        const socket = io();
        
        // Load log files list
        fetch('/api/logs')
            .then(response => response.json())
            .then(files => {
                const logFilesContainer = document.getElementById('log-files');
                logFilesContainer.innerHTML = '';
                
                files.forEach(file => {
                    const logItem = document.createElement('a');
                    logItem.href = '#';
                    logItem.className = 'list-group-item list-group-item-action';
                    logItem.textContent = file;
                    logItem.addEventListener('click', () => loadLog(file));
                    logFilesContainer.appendChild(logItem);
                });
                
                if (files.length > 0) {
                    loadLog(files[0]);
                }
            });
        
        // Load log content
        function loadLog(filename) {
            fetch('/api/log/' + filename)
                .then(response => response.text())
                .then(content => {
                    document.getElementById('log-content').textContent = content;
                });
        }
        
        // Update server info in real-time
        socket.on('server_update', (data) => {
            document.getElementById('hostname').textContent = data.hostname;
            document.getElementById('ip').textContent = data.ip;
            document.getElementById('uptime').textContent = data.uptime;
            document.getElementById('loadavg').textContent = data.loadavg;
        });
        
        // Request initial server info
        socket.emit('get_server_info');
    </script>
</body>
</html>`;
    
    await fs.writeFile(path.join(publicDir, 'index.html'), indexHtml);
}

// Setup and start server
setupPublic().then(() => {
    // Install dependencies
    const { execSync } = require('child_process');
    console.log('Installing dependencies...');
    execSync('npm install', { cwd: __dirname, stdio: 'inherit' });

    // Start server
    const PORT = process.env.PORT || 3000;
    http.listen(PORT, '0.0.0.0', () => {
        console.log('Server running on http://0.0.0.0:' + PORT);
    });

    // Real-time updates
    setInterval(() => {
        const os = require('os');
        const hostname = os.hostname();
        const uptime = os.uptime();
        const loadavg = os.loadavg();
        
        // Format uptime
        const days = Math.floor(uptime / 86400);
        const hours = Math.floor((uptime % 86400) / 3600);
        const minutes = Math.floor((uptime % 3600) / 60);
        const uptimeStr = days + 'd ' + hours + 'h ' + minutes + 'm';
        
        io.emit('server_update', {
            hostname: hostname,
            ip: process.env.SERVER_IP || 'N/A',
            uptime: uptimeStr,
            loadavg: loadavg.map(v => v.toFixed(2)).join(', ')
        });
    }, 5000);
}).catch(err => {
    console.error('Failed to setup server:', err);
});
EOL

    # Install dependencies and start web panel
    cd "$WEB_PANEL_DIR"
    npm install
    
    # Check if web panel is already running
    if ! pgrep -f "node.*server.js" > /dev/null; then
        nohup node server.js > "$WEB_PANEL_DIR/server.log" 2>&1 &
        print "${GREEN}Web panel started on port $WEB_PANEL_PORT${NC}"
    else
        print "${YELLOW}Web panel is already running${NC}"
    fi
    
    # Check firewall
    if command -v ufw &> /dev/null; then
        if ! ufw status | grep -q "$WEB_PANEL_PORT/tcp"; then
            ufw allow "$WEB_PANEL_PORT/tcp"
            print "${GREEN}Firewall rule added for port $WEB_PANEL_PORT${NC}"
        fi
    fi
    
    print "Access the dashboard at: ${GREEN}http://$IP:$WEB_PANEL_PORT${NC}"
else
    print "${YELLOW}Web panel is disabled (WEB_PANEL_ENABLE=false)${NC}"
fi

section "⏰ SETUP CRONJOB"
CRON_JOB="0 * * * * root $(realpath "$0")"
CRON_FILE="/etc/cron.d/server_monitor"

if [ ! -f "$CRON_FILE" ] || ! grep -q "$(realpath "$0")" "$CRON_FILE"; then
    echo "$CRON_JOB" | sudo tee "$CRON_FILE" > /dev/null
    sudo chmod 644 "$CRON_FILE"
    print "${GREEN}Cronjob created to run hourly at $CRON_FILE${NC}"
else
    print "${YELLOW}Cronjob already exists at $CRON_FILE${NC}"
fi

section "📤 KIRIM LAPORAN (TELEGRAM)"
if [ "$KIRIM_TELEGRAM" = true ]; then
    if curl -s -F chat_id="$TELEGRAM_CHAT_ID" \
         -F document=@"$LOGFILE" \
         -F caption="📊 Laporan Monitoring: $(date)" \
         "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" >/dev/null; then
        print "${GREEN}✅ Laporan berhasil dikirim ke Telegram.${NC}"
    else
        print "${RED}❌ Gagal mengirim laporan ke Telegram.${NC}"
    fi
else
    print "${YELLOW}Laporan TIDAK dikirim (KIRIM_TELEGRAM=false)${NC}"
fi

section "✅ MONITORING SELESAI"
print "Log disimpan di: ${GREEN}$LOGFILE${NC}"

if [ "$WEB_PANEL_ENABLE" = true ]; then
    print "Web panel berjalan di port: ${GREEN}$WEB_PANEL_PORT${NC}"
    print "Akses dashboard di: ${GREEN}http://$IP:$WEB_PANEL_PORT${NC}"
    print "Untuk menghentikan web panel: ${RED}kill \$(pgrep -f 'node.*server.js')${NC}"
    print "Untuk melihat log web panel: ${YELLOW}cat /opt/server-monitor/server.log${NC}"
fi