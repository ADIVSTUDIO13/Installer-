#!/bin/bash

echo "=== AUTO SETUP VNC SERVER KALI/UBUNTU ==="

# Update & install XFCE + VNC
apt update && apt install xfce4 xfce4-goodies tigervnc-standalone-server -y

# Set password VNC (default: 123456)
echo "123456" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Buat file Xresources kalau belum ada
touch ~/.Xresources

# Buat file xstartup
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<EOF
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Kill session lama (kalau ada)
vncserver -kill :1 > /dev/null 2>&1
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC
vncserver :1 -geometry 1280x720 -depth 24

# Buka firewall jika pakai UFW
if command -v ufw &> /dev/null; then
  ufw allow 5901/tcp
fi

echo ""
echo "=== SETUP SELESAI ==="
echo "Gunakan VNC Viewer ke: $(curl -s ifconfig.me):5901"
echo "Password VNC default: 123456"
echo "Jika ingin ganti password: jalankan vncpasswd"
