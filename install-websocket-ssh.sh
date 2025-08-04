#!/bin/bash

# WebSocket SSH Installer untuk HTTP Injector
# Script ini akan menginstall dan mengkonfigurasi OpenSSH, Dropbear, dan ws-epro
# Untuk digunakan dengan HTTP Injector melalui WebSocket

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Jangan jalankan script ini sebagai root!"
        print_status "Gunakan: bash install-websocket-ssh.sh"
        exit 1
    fi
}

# Check sudo access
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_status "Script ini memerlukan akses sudo. Silakan masukkan password jika diminta."
        sudo -v
    fi
}

# Update system packages
update_system() {
    print_header "=== Updating System Packages ==="
    sudo apt update -y
    print_status "System packages updated successfully"
}

# Install required packages
install_packages() {
    print_header "=== Installing Required Packages ==="
    
    print_status "Installing OpenSSH Server and Dropbear..."
    sudo apt install -y openssh-server dropbear-bin curl
    
    print_status "Packages installed successfully"
}

# Download and install ws-epro
install_ws_epro() {
    print_header "=== Installing ws-epro WebSocket Proxy ==="
    
    print_status "Downloading ws-epro from GitHub..."
    sudo curl -L -o /usr/local/bin/ws-epro https://raw.githubusercontent.com/essoojay/PROXY-SSH-OVER-CDN/master/ws-epro/ws-epro
    
    print_status "Setting executable permissions..."
    sudo chmod +x /usr/local/bin/ws-epro
    
    print_status "ws-epro installed successfully"
}

# Create ws-epro configuration
create_config() {
    print_header "=== Creating Configuration Files ==="
    
    # Create config directory
    sudo mkdir -p /etc/ws-epro
    
    # Create ws-epro config
    print_status "Creating ws-epro configuration..."
    sudo tee /etc/ws-epro/config.yml > /dev/null <<EOF
# verbose level 0=info, 1=verbose, 2=very verbose
verbose: 1
listen:
  # openssh
  - target_host: 127.0.0.1
    target_port: 22
    listen_port: 8080

  # dropbear  
  - target_host: 127.0.0.1
    target_port: 2222
    listen_port: 8081
EOF
    
    print_status "Configuration files created successfully"
}

# Create systemd service
create_systemd_service() {
    print_header "=== Creating Systemd Services ==="
    
    # Create ws-epro service
    print_status "Creating ws-epro systemd service..."
    sudo tee /etc/systemd/system/ws-epro.service > /dev/null <<EOF
[Unit]
Description=WebSocket to SSH/Dropbear Proxy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    if systemctl --version >/dev/null 2>&1; then
        print_status "Reloading systemd daemon..."
        sudo systemctl daemon-reload
        sudo systemctl enable ws-epro 2>/dev/null || print_warning "Could not enable ws-epro service (systemd might not be available)"
        sudo systemctl enable ssh 2>/dev/null || print_warning "Could not enable ssh service (systemd might not be available)"
    else
        print_warning "Systemd not available, services will need to be started manually"
    fi
    
    print_status "Systemd services configured"
}

# Create startup script
create_startup_script() {
    print_header "=== Creating Startup Script ==="
    
    print_status "Creating startup script..."
    tee ~/start-websocket-ssh.sh > /dev/null <<'EOF'
#!/bin/bash

# WebSocket SSH Startup Script
# Untuk HTTP Injector dengan WebSocket

echo "=== Starting WebSocket SSH Services ==="

# Stop existing processes
echo "Stopping existing processes..."
sudo pkill sshd 2>/dev/null || true
sudo pkill dropbear 2>/dev/null || true
sudo pkill ws-epro 2>/dev/null || true

sleep 2

# Start SSH on port 22
echo "Starting OpenSSH on port 22..."
sudo /usr/sbin/sshd -p 22

# Start Dropbear on port 2222
echo "Starting Dropbear on port 2222..."
sudo dropbear -p 2222 -F &

# Wait for services to start
sleep 3

# Start ws-epro WebSocket proxy
echo "Starting ws-epro WebSocket proxy..."
/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml &

# Wait for ws-epro to start
sleep 3

echo ""
echo "=== Service Status ==="

# Check SSH
if pgrep sshd > /dev/null; then
    echo "✓ OpenSSH is running on port 22"
else
    echo "✗ OpenSSH failed to start"
fi

# Check Dropbear
if pgrep dropbear > /dev/null; then
    echo "✓ Dropbear is running on port 2222"
else
    echo "✗ Dropbear failed to start"
fi

# Check ws-epro
if pgrep ws-epro > /dev/null; then
    echo "✓ ws-epro WebSocket proxy is running"
    echo ""
    echo "=== WebSocket URLs for HTTP Injector ==="
    echo "SSH (OpenSSH):  ws://$(curl -s ifconfig.me):8080"
    echo "SSH (Dropbear): ws://$(curl -s ifconfig.me):8081"
else
    echo "✗ ws-epro failed to start"
fi

echo ""
echo "=== Configuration for HTTP Injector ==="
echo "1. Open HTTP Injector"
echo "2. Select Custom SSH"
echo "3. Set Connection Type: WebSocket"
echo "4. Use the WebSocket URLs shown above"
echo ""
EOF
    
    chmod +x ~/start-websocket-ssh.sh
    print_status "Startup script created at ~/start-websocket-ssh.sh"
}

# Configure SSH
configure_ssh() {
    print_header "=== Configuring SSH ==="
    
    # Backup original sshd_config
    if [ -f /etc/ssh/sshd_config ]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        print_status "SSH configuration backed up"
    fi
    
    # Ensure SSH is configured properly
    print_status "Configuring SSH settings..."
    sudo sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config 2>/dev/null || true
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
    
    print_status "SSH configured successfully"
}

# Configure firewall (if ufw is available)
configure_firewall() {
    print_header "=== Configuring Firewall ==="
    
    if command -v ufw >/dev/null 2>&1; then
        print_status "Configuring UFW firewall..."
        sudo ufw allow 22/tcp 2>/dev/null || true
        sudo ufw allow 2222/tcp 2>/dev/null || true
        sudo ufw allow 8080/tcp 2>/dev/null || true
        sudo ufw allow 8081/tcp 2>/dev/null || true
        print_status "Firewall rules added for ports 22, 2222, 8080, 8081"
    else
        print_warning "UFW firewall not found. Please manually open ports 22, 2222, 8080, 8081"
    fi
}

# Start services
start_services() {
    print_header "=== Starting Services ==="
    
    if systemctl --version >/dev/null 2>&1; then
        print_status "Starting services with systemd..."
        sudo systemctl start ssh 2>/dev/null || print_warning "Could not start SSH via systemd"
        sudo systemctl start ws-epro 2>/dev/null || print_warning "Could not start ws-epro via systemd"
    else
        print_status "Starting services manually..."
        ~/start-websocket-ssh.sh
    fi
}

# Create documentation
create_documentation() {
    print_header "=== Creating Documentation ==="
    
    tee ~/README-WebSocket-SSH.md > /dev/null <<'EOF'
# WebSocket SSH untuk HTTP Injector

## Instalasi Berhasil!

Script installer telah mengkonfigurasi sistem Anda untuk menggunakan SSH melalui WebSocket dengan HTTP Injector.

## Komponen yang Terinstall

1. **OpenSSH Server** - Port 22
2. **Dropbear SSH** - Port 2222  
3. **ws-epro** - WebSocket Proxy

## Port Mapping

| Service | Local Port | WebSocket Port | 
|---------|------------|----------------|
| OpenSSH | 22 | 8080 |
| Dropbear | 2222 | 8081 |

## Cara Menjalankan

```bash
# Jalankan semua services
~/start-websocket-ssh.sh
```

## Konfigurasi HTTP Injector

### Untuk OpenSSH:
- **Host:** IP_SERVER_ANDA
- **Port:** 8080
- **Protocol:** WebSocket (ws://)

### Untuk Dropbear:
- **Host:** IP_SERVER_ANDA  
- **Port:** 8081
- **Protocol:** WebSocket (ws://)

## File Penting

- Config: `/etc/ws-epro/config.yml`
- Startup: `~/start-websocket-ssh.sh`
- Service: `/etc/systemd/system/ws-epro.service`

## Troubleshooting

```bash
# Restart services
~/start-websocket-ssh.sh

# Check status
ps aux | grep -E "(sshd|dropbear|ws-epro)"

# Test WebSocket
curl -I http://localhost:8080
curl -I http://localhost:8081
```

## Security

1. Ganti password default
2. Gunakan SSH keys
3. Monitor logs secara berkala
4. Update sistem secara rutin

---
Generated by WebSocket SSH Installer
EOF
    
    print_status "Documentation created at ~/README-WebSocket-SSH.md"
}

# Test installation
test_installation() {
    print_header "=== Testing Installation ==="
    
    # Test ws-epro binary
    if /usr/local/bin/ws-epro --help >/dev/null 2>&1; then
        print_status "✓ ws-epro binary is working"
    else
        print_error "✗ ws-epro binary test failed"
    fi
    
    # Test configuration file
    if [ -f /etc/ws-epro/config.yml ]; then
        print_status "✓ Configuration file exists"
    else
        print_error "✗ Configuration file missing"
    fi
    
    # Test startup script
    if [ -x ~/start-websocket-ssh.sh ]; then
        print_status "✓ Startup script is executable"
    else
        print_error "✗ Startup script test failed"
    fi
}

# Main installation function
main() {
    print_header "=========================================="
    print_header "  WebSocket SSH Installer for HTTP Injector"
    print_header "=========================================="
    echo ""
    
    check_root
    check_sudo
    
    print_status "Starting installation process..."
    echo ""
    
    update_system
    install_packages
    install_ws_epro
    create_config
    create_systemd_service
    create_startup_script
    configure_ssh
    configure_firewall
    create_documentation
    test_installation
    
    echo ""
    print_header "=========================================="
    print_header "           INSTALLATION COMPLETE!"
    print_header "=========================================="
    echo ""
    
    print_status "WebSocket SSH berhasil dikonfigurasi!"
    echo ""
    echo -e "${GREEN}Langkah selanjutnya:${NC}"
    echo "1. Jalankan services: ${YELLOW}~/start-websocket-ssh.sh${NC}"
    echo "2. Baca dokumentasi: ${YELLOW}~/README-WebSocket-SSH.md${NC}"
    echo "3. Konfigurasi HTTP Injector dengan WebSocket URLs yang ditampilkan"
    echo ""
    echo -e "${GREEN}WebSocket URLs:${NC}"
    echo "- SSH (OpenSSH):  ws://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP'):8080"
    echo "- SSH (Dropbear): ws://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP'):8081"
    echo ""
    
    # Auto-start services if requested
    read -p "Apakah Anda ingin menjalankan services sekarang? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Starting services..."
        ~/start-websocket-ssh.sh
    else
        print_status "Anda dapat menjalankan services kapan saja dengan: ~/start-websocket-ssh.sh"
    fi
}

# Run main function
main "$@"