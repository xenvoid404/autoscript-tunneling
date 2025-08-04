#!/bin/bash

# Quick Install Script untuk Autoscript Tunneling
# Script untuk download dan install autoscript tunneling

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi logging
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# URL untuk download script (ganti dengan URL yang sesuai)
SCRIPT_URL="https://raw.githubusercontent.com/your-repo/autoscript-tunnel/main/autoscript-tunnel.sh"
SCRIPT_NAME="autoscript-tunnel.sh"
TEMP_DIR="/tmp/autoscript-tunnel"

# Fungsi untuk mengecek apakah script dijalankan sebagai root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan sebagai root!"
        print_info "Gunakan: sudo bash $0"
        exit 1
    fi
}

# Fungsi untuk mengecek koneksi internet
check_internet() {
    print_info "Mengecek koneksi internet..."
    
    if ping -c 1 google.com >/dev/null || ping -c 1 8.8.8.8 >/dev/null; then
        print_success "Koneksi internet tersedia"
        return 0
    else
        print_error "Tidak ada koneksi internet"
        print_info "Pastikan server terhubung ke internet untuk download script"
        return 1
    fi
}

# Fungsi untuk install dependencies
install_dependencies() {
    print_info "Menginstall dependencies..."
    
    # Update package list
    apt update -y
    
    # Install wget dan curl jika belum ada
    local deps_needed=""
    
    if ! command -v wget; then
        deps_needed="$deps_needed wget"
    fi
    
    if ! command -v curl; then
        deps_needed="$deps_needed curl"
    fi
    
    if [ -n "$deps_needed" ]; then
        print_info "Installing: $deps_needed"
        apt install -y $deps_needed
        
        if [ $? -eq 0 ]; then
            print_success "Dependencies berhasil diinstall"
        else
            print_error "Gagal menginstall dependencies"
            exit 1
        fi
    else
        print_success "Semua dependencies sudah tersedia"
    fi
}

# Fungsi untuk download script
download_script() {
    print_info "Mendownload autoscript tunneling..."
    
    # Buat direktori temporary
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download menggunakan wget atau curl
    if command -v wget >/dev/null 2>&1; then
        wget -O "$SCRIPT_NAME" "$SCRIPT_URL" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -o "$SCRIPT_NAME" "$SCRIPT_URL" 2>/dev/null
    else
        print_error "wget atau curl tidak tersedia"
        exit 1
    fi
    
    if [ $? -eq 0 ] && [ -f "$SCRIPT_NAME" ]; then
        print_success "Script berhasil didownload"
        chmod +x "$SCRIPT_NAME"
    else
        print_error "Gagal mendownload script"
        print_info "Coba download manual dari: $SCRIPT_URL"
        exit 1
    fi
}

# Fungsi untuk menjalankan script utama
run_main_script() {
    print_info "Menjalankan autoscript tunneling..."
    echo
    echo "=============================================="
    echo
    
    # Jalankan script utama
    bash "$TEMP_DIR/$SCRIPT_NAME"
    
    local exit_code=$?
    
    echo
    echo "=============================================="
    
    if [ $exit_code -eq 0 ]; then
        print_success "Instalasi selesai!"
    else
        print_error "Instalasi gagal dengan exit code: $exit_code"
        exit $exit_code
    fi
}

# Fungsi untuk cleanup
cleanup() {
    print_info "Membersihkan file temporary..."
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_success "File temporary dibersihkan"
    fi
}

# Fungsi untuk menampilkan informasi
show_info() {
    clear
    echo "=============================================="
    echo "    AUTOSCRIPT TUNNELING QUICK INSTALLER"
    echo "    Debian 11/12 & Ubuntu 22/24"
    echo "=============================================="
    echo
    print_info "Pilih mode instalasi:"
    echo "  1. Standard Tunneling (SSH + Dropbear)"
    echo "  2. WebSocket SSH untuk HTTP Injector"
    echo "  3. Install keduanya (Standard + WebSocket)"
    echo
    print_warning "Pastikan Anda menjalankan script ini di fresh VPS"
    print_warning "atau backup konfigurasi SSH yang ada terlebih dahulu"
    echo
}

# Fungsi untuk install WebSocket SSH
install_websocket_ssh() {
    print_info "=== Installing WebSocket SSH untuk HTTP Injector ==="
    
    # Install packages
    print_info "Installing required packages..."
    apt install -y openssh-server dropbear-bin curl
    
    # Download ws-epro
    print_info "Downloading ws-epro WebSocket proxy..."
    curl -sL -o /usr/local/bin/ws-epro https://raw.githubusercontent.com/essoojay/PROXY-SSH-OVER-CDN/master/ws-epro/ws-epro
    chmod +x /usr/local/bin/ws-epro
    
    # Create config directory
    mkdir -p /etc/ws-epro
    
    # Create ws-epro configuration
    print_info "Creating WebSocket configuration..."
    cat > /etc/ws-epro/config.yml << 'EOF'
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
    
    # Create systemd service
    print_info "Creating systemd service..."
    cat > /etc/systemd/system/ws-epro.service << 'EOF'
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
    
    # Create startup script
    print_info "Creating startup script..."
    cat > /root/start-websocket-ssh.sh << 'EOF'
#!/bin/bash

echo "=== Starting WebSocket SSH Services ==="

# Stop existing processes
sudo pkill sshd dropbear ws-epro 2>/dev/null || true
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

# Check services
if pgrep sshd > /dev/null; then
    echo "✓ OpenSSH is running on port 22"
else
    echo "✗ OpenSSH failed to start"
fi

if pgrep dropbear > /dev/null; then
    echo "✓ Dropbear is running on port 2222"
else
    echo "✗ Dropbear failed to start"
fi

if pgrep ws-epro > /dev/null; then
    echo "✓ ws-epro WebSocket proxy is running"
    echo ""
    echo "=== WebSocket URLs for HTTP Injector ==="
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    echo "SSH (OpenSSH):  ws://${SERVER_IP}:8080"
    echo "SSH (Dropbear): ws://${SERVER_IP}:8081"
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
    
    chmod +x /root/start-websocket-ssh.sh
    
    # Configure firewall if available
    if command -v ufw >/dev/null 2>&1; then
        print_info "Configuring firewall..."
        ufw allow 22,2222,8080,8081/tcp 2>/dev/null || true
    fi
    
    # Enable and start services
    if systemctl --version >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable ws-epro ssh 2>/dev/null || true
    fi
    
    print_success "WebSocket SSH installation completed!"
    
    # Show WebSocket URLs
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    echo
    print_info "=== WebSocket URLs for HTTP Injector ==="
    echo "SSH (OpenSSH):  ws://${SERVER_IP}:8080"
    echo "SSH (Dropbear): ws://${SERVER_IP}:8081"
    echo
    print_info "Startup script: /root/start-websocket-ssh.sh"
    echo
}

# Fungsi offline mode (jika script sudah ada)
offline_mode() {
    local local_script="./autoscript-tunnel.sh"
    
    if [ -f "$local_script" ]; then
        print_info "Script ditemukan di direktori lokal"
        echo -n "Gunakan script lokal? (y/n): "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                print_info "Menggunakan script lokal..."
                chmod +x "$local_script"
                bash "$local_script"
                exit $?
                ;;
        esac
    fi
}

# Fungsi utama
main() {
    # Tampilkan informasi
    show_info
    
    # Cek root
    check_root
    
    # Cek offline mode (hanya untuk standard mode)
    if [ "$1" != "--websocket" ]; then
        offline_mode
    fi
    
    # Konfirmasi dan pilih mode
    confirm_installation
    
    # Cek koneksi internet
    if ! check_internet; then
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    
    # Execute based on selected mode
    case "$INSTALL_MODE" in
        "standard")
            # Download script
            download_script
            
            # Jalankan script utama
            run_main_script
            
            # Cleanup
            cleanup
            
            echo
            print_success "=============================================="
            print_success "    STANDARD TUNNELING INSTALL SELESAI!"
            print_success "=============================================="
            echo
            print_info "Autoscript tunneling telah berhasil diinstall"
            print_info "Anda sekarang dapat menggunakan SSH tunneling"
            ;;
            
        "websocket")
            # Install WebSocket SSH
            install_websocket_ssh
            
            echo
            print_success "=============================================="
            print_success "    WEBSOCKET SSH INSTALL SELESAI!"
            print_success "=============================================="
            echo
            print_info "WebSocket SSH untuk HTTP Injector telah berhasil diinstall"
            print_info "Gunakan /root/start-websocket-ssh.sh untuk menjalankan services"
            ;;
            
        "both")
            # Install WebSocket SSH first
            install_websocket_ssh
            
            echo
            print_info "=============================================="
            print_info "    MELANJUTKAN KE STANDARD TUNNELING..."
            print_info "=============================================="
            echo
            
            # Download script
            download_script
            
            # Jalankan script utama
            run_main_script
            
            # Cleanup
            cleanup
            
            echo
            print_success "=============================================="
            print_success "    SEMUA INSTALASI SELESAI!"
            print_success "=============================================="
            echo
            print_info "Standard tunneling dan WebSocket SSH telah berhasil diinstall"
            print_info "WebSocket SSH: /root/start-websocket-ssh.sh"
            print_info "Standard tunneling: Ikuti instruksi di atas"
            ;;
    esac
    
    echo
    print_info "Untuk test instalasi, jalankan:"
    echo "  wget -O test.sh https://raw.githubusercontent.com/your-repo/test-tunnel.sh"
    echo "  chmod +x test.sh && ./test.sh"
    echo
}

# Fungsi untuk menampilkan help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --websocket    Install WebSocket SSH only untuk HTTP Injector"
    echo "  --standard     Install Standard Tunneling only"
    echo "  --both         Install both WebSocket SSH dan Standard Tunneling"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode"
    echo "  $0 --websocket       # Install WebSocket SSH only"
    echo "  $0 --both            # Install both modes"
    echo ""
}

# Parse command line arguments
parse_args() {
    case "$1" in
        --websocket)
            INSTALL_MODE="websocket"
            NON_INTERACTIVE=true
            ;;
        --standard)
            INSTALL_MODE="standard"
            NON_INTERACTIVE=true
            ;;
        --both)
            INSTALL_MODE="both"
            NON_INTERACTIVE=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # Interactive mode
            NON_INTERACTIVE=false
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Modified confirm_installation for non-interactive mode
confirm_installation() {
    if [ "$NON_INTERACTIVE" = true ]; then
        case "$INSTALL_MODE" in
            "standard")
                print_info "Mode: Standard Tunneling (non-interactive)"
                ;;
            "websocket")
                print_info "Mode: WebSocket SSH (non-interactive)"
                ;;
            "both")
                print_info "Mode: Standard + WebSocket (non-interactive)"
                ;;
        esac
        return 0
    fi
    
    echo -n "Pilih mode instalasi (1/2/3): "
    read -r choice
    
    case "$choice" in
        1)
            INSTALL_MODE="standard"
            print_info "Mode: Standard Tunneling dipilih"
            ;;
        2)
            INSTALL_MODE="websocket"
            print_info "Mode: WebSocket SSH dipilih"
            ;;
        3)
            INSTALL_MODE="both"
            print_info "Mode: Standard + WebSocket dipilih"
            ;;
        *)
            print_error "Pilihan tidak valid"
            exit 1
            ;;
    esac
    
    echo
    echo -n "Lanjutkan instalasi? (y/n): "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            print_info "Instalasi dibatalkan oleh user"
            exit 0
            ;;
    esac
}

# Trap untuk cleanup saat script dihentikan
trap cleanup EXIT

# Parse arguments and run main function
parse_args "$1"
main "$@"