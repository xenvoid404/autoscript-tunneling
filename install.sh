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
SCRIPT_URL="https://raw.githubusercontent.com/xenvoid/autoscript-tunneling/master/autoscript-tunnel.sh"
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
    print_info "Script ini akan:"
    echo "  1. Download autoscript tunneling terbaru"
    echo "  2. Install dan konfigurasi OpenSSH"
    echo "  3. Install dan konfigurasi Dropbear"
    echo "  4. Setup multiple port untuk tunneling"
    echo "  5. Enable auto-start services"
    echo
    print_warning "Pastikan Anda menjalankan script ini di fresh VPS"
    print_warning "atau backup konfigurasi SSH yang ada terlebih dahulu"
    echo
}

# Fungsi untuk konfirmasi user
confirm_installation() {
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
    
    # Cek offline mode
    offline_mode
    
    # Konfirmasi
    confirm_installation
    
    # Cek koneksi internet
    if ! check_internet; then
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    
    # Download script
    download_script
    
    # Jalankan script utama
    run_main_script
    
    # Cleanup
    cleanup
    
    echo
    print_success "=============================================="
    print_success "    QUICK INSTALL SELESAI!"
    print_success "=============================================="
    echo
    print_info "Autoscript tunneling telah berhasil diinstall"
    print_info "Anda sekarang dapat menggunakan SSH tunneling"
    echo
    print_info "Untuk test instalasi, jalankan:"
    echo "  wget -O test.sh https://raw.githubusercontent.com/your-repo/test-tunnel.sh"
    echo "  chmod +x test.sh && ./test.sh"
    echo
}

# Trap untuk cleanup saat script dihentikan
trap cleanup EXIT

# Jalankan fungsi utama
main "$@"