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

# Fungsi untuk menjalankan script SSH
run_ssh_script() {
    print_info "Menjalankan installer SSH..."
    echo
    echo "=============================================="
    echo
    
    # Jalankan script SSH
    bash "./installer/ssh.sh"
    
    local exit_code=$?
    
    echo
    echo "=============================================="
    
    if [ $exit_code -eq 0 ]; then
        print_success "Instalasi SSH selesai!"
    else
        print_error "Instalasi SSH gagal dengan exit code: $exit_code"
        exit $exit_code
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
    echo "  1. Install dan konfigurasi OpenSSH"
    echo "  2. Install dan konfigurasi Dropbear"
    echo "  3. Setup WebSocket proxy (ws-epro)"
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

# Fungsi utama
main() {
    # Tampilkan informasi
    show_info
    
    # Cek root
    check_root
    
    # Konfirmasi
    confirm_installation
    
    # Cek koneksi internet
    if ! check_internet; then
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    
    # Jalankan script SSH
    run_ssh_script
    
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

# Jalankan fungsi utama
main "$@"