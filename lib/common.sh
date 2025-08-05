#!/bin/bash

# Library functions untuk autoscript tunneling
# Author: Xenvoid404
# Version: 1.0

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

# Fungsi validasi dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Fungsi download dengan error handling
download_file() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -sSfL "$url" -o "$output"; then
            print_success "Downloaded: $output"
            return 0
        else
            retry=$((retry + 1))
            print_warning "Download failed, retry $retry/$max_retries"
            sleep 2
        fi
    done
    
    print_error "Failed to download: $url"
    return 1
}

# Fungsi validasi file
validate_file() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        print_error "$description not found: $file"
        return 1
    fi
    
    if [ ! -s "$file" ]; then
        print_error "$description is empty: $file"
        return 1
    fi
    
    return 0
}

# Fungsi rollback
rollback_installation() {
    local service="$1"
    print_warning "Rolling back $service installation..."
    
    case "$service" in
        "xray")
            systemctl stop spectrum quantix cipheron 2>/dev/null
            systemctl disable spectrum quantix cipheron 2>/dev/null
            rm -rf /etc/default/layers
            rm -f /usr/local/bin/ws-epro
            ;;
        "openvpn")
            systemctl stop openvpn-server@server-tcp-1194 2>/dev/null
            systemctl stop openvpn-server@server-udp-25000 2>/dev/null
            systemctl disable openvpn-server@server-tcp-1194 2>/dev/null
            systemctl disable openvpn-server@server-udp-25000 2>/dev/null
            rm -rf /etc/openvpn
            ;;
        "certificate")
            rm -rf /etc/certificates
            ;;
    esac
}

# Fungsi validasi port
validate_port() {
    local port="$1"
    local service="$2"
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "Invalid port for $service: $port"
        return 1
    fi
    
    if netstat -tuln | grep -q ":$port "; then
        print_warning "Port $port is already in use"
        return 1
    fi
    
    return 0
}

# Fungsi backup konfigurasi
backup_config() {
    local config_dir="$1"
    local backup_dir="/root/backup/$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "$config_dir" ]; then
        mkdir -p "$backup_dir"
        cp -r "$config_dir" "$backup_dir/"
        print_success "Backup created: $backup_dir"
    fi
}

# Fungsi restore konfigurasi
restore_config() {
    local backup_dir="$1"
    local config_dir="$2"
    
    if [ -d "$backup_dir" ]; then
        cp -r "$backup_dir"/* "$config_dir/"
        print_success "Config restored from: $backup_dir"
        return 0
    else
        print_error "Backup not found: $backup_dir"
        return 1
    fi
}