#!/bin/bash

# =============================================================================
# Modern Tunneling Autoinstaller v4.0.0
# Complete Production-Ready Installation Script
# 
# Features:
# - One-command installation
# - Comprehensive error handling
# - Production-ready configurations
# - Automatic SSL certificate generation
# - System optimization
# - Firewall configuration
# - Service management
# - Health checks and validation
#
# Author: Yuipedia
# License: MIT
# Compatible: Debian 11+, Ubuntu 22.04+
# =============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Installation directories
readonly INSTALL_DIR="/opt/autoscript"
readonly CONFIG_DIR="/etc/autoscript"
readonly BIN_DIR="/usr/local/bin"
readonly LOG_DIR="/var/log/autoscript"
readonly XRAY_CONFIG_DIR="/etc/xray"
readonly SSL_DIR="/etc/xray/ssl"

# GitHub repository configuration
readonly GITHUB_USER="xenvoid404"
readonly GITHUB_REPO="autoscript-tunneling"
readonly GITHUB_BRANCH="master"
readonly REPO_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Logging
readonly LOG_FILE="/var/log/autoscript-install.log"
readonly ERROR_LOG="/var/log/autoscript-error.log"

# Global variables
SCRIPT_START_TIME=$(date +%s)
INSTALLATION_SUCCESS=false
ERROR_COUNT=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" -a "$ERROR_LOG"
    ((ERROR_COUNT++))
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command=$2
    
    log_error "Command failed at line $line_number: $command (exit code: $exit_code)"
    
    if [[ $ERROR_COUNT -gt 5 ]]; then
        log_error "Too many errors encountered. Installation failed."
        cleanup_on_failure
        exit 1
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    log_warning "Cleaning up after installation failure..."
    
    # Stop services that might have been started
    systemctl stop xray-vmess xray-vless xray-trojan nginx 2>/dev/null || true
    
    # Remove systemd service files
    rm -f /etc/systemd/system/xray-*.service 2>/dev/null || true
    
    # Reload systemd
    systemctl daemon-reload 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Check system compatibility
check_system_compatibility() {
    log_section "System Compatibility Check"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS information"
        exit 1
    fi
    
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    
    # Version comparison function
    version_compare() {
        local version1=$1
        local operator=$2  
        local version2=$3
        
        local v1_major=$(echo "$version1" | cut -d. -f1)
        local v1_minor=$(echo "$version1" | cut -d. -f2 2>/dev/null || echo "0")
        local v2_major=$(echo "$version2" | cut -d. -f1)
        local v2_minor=$(echo "$version2" | cut -d. -f2 2>/dev/null || echo "0")
        
        if [[ "$v1_minor" =~ ^[0-9]+$ ]] && [[ ${#v1_minor} -eq 1 ]]; then
            v1_minor=$((v1_minor * 10))
        fi
        if [[ "$v2_minor" =~ ^[0-9]+$ ]] && [[ ${#v2_minor} -eq 1 ]]; then
            v2_minor=$((v2_minor * 10))
        fi
        
        local v1_int=$((v1_major * 100 + v1_minor))
        local v2_int=$((v2_major * 100 + v2_minor))
        
        case $operator in
            ">=") [[ $v1_int -ge $v2_int ]] ;;
            ">") [[ $v1_int -gt $v2_int ]] ;;
            "=") [[ $v1_int -eq $v2_int ]] ;;
            "<") [[ $v1_int -lt $v2_int ]] ;;
            "<=") [[ $v1_int -le $v2_int ]] ;;
            *) return 1 ;;
        esac
    }
    
    # Check OS compatibility
    case $OS in
        "Ubuntu")
            if ! version_compare "$VER" ">=" "22.04"; then
                log_error "Ubuntu 22.04+ required. Current: $VER"
                exit 1
            fi
            ;;
        "Debian GNU/Linux")
            if ! version_compare "$VER" ">=" "11"; then
                log_error "Debian 11+ required. Current: $VER"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported OS: $OS"
            echo "Supported: Ubuntu 22.04+ or Debian 11+"
            exit 1
            ;;
    esac
    
    log_success "System compatibility check passed: $OS $VER"
}

# Check internet connectivity
check_internet() {
    log_section "Internet Connectivity Check"
    
    local test_urls=("8.8.8.8" "1.1.1.1" "github.com")
    local success_count=0
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
            ((success_count++))
        fi
    done
    
    if [[ $success_count -ge 2 ]]; then
        log_success "Internet connectivity confirmed"
        return 0
    else
        log_error "Internet connectivity issues detected"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    log_section "Disk Space Check"
    
    local required_space=500 # MB
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local available_mb=$((available_space / 1024))
    
    if [[ $available_mb -lt $required_space ]]; then
        log_error "Insufficient disk space. Required: ${required_space}MB, Available: ${available_mb}MB"
        return 1
    else
        log_success "Disk space check passed: ${available_mb}MB available"
        return 0
    fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Create directory structure
create_directory_structure() {
    log_section "Creating Directory Structure"
    
    local directories=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/scripts"
        "$INSTALL_DIR/scripts/services"
        "$INSTALL_DIR/scripts/accounts" 
        "$INSTALL_DIR/scripts/system"
        "$INSTALL_DIR/utils"
        "$INSTALL_DIR/config"
        "$CONFIG_DIR"
        "$CONFIG_DIR/accounts"
        "$LOG_DIR"
        "$XRAY_CONFIG_DIR"
        "$SSL_DIR"
        "/var/lib/autoscript"
        "/usr/local/bin/autoscript-mgmt"
        "/usr/local/bin/xray-mgmt"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir" && chmod 755 "$dir"; then
            log_info "Created directory: $dir"
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    done
    
    log_success "Directory structure created successfully"
}

# Download file with retry mechanism
download_file_with_retry() {
    local url="$1"
    local destination="$2"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        log_info "Downloading $(basename "$destination") (attempt $attempt/$max_attempts)..."
        
        if wget -q --show-progress --timeout=30 --tries=2 -O "$destination" "$url" 2>/dev/null; then
            log_success "Downloaded: $(basename "$destination")"
            return 0
        else
            log_warning "Download attempt $attempt failed"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 2
            fi
        fi
    done
    
    log_error "Failed to download after $max_attempts attempts: $url"
    return 1
}

# Download and install autoscript files
download_autoscript_files() {
    log_section "Downloading Autoscript Files"
    
    # Define files to download with their destinations
    declare -A files_to_download=(
        # Utility files
        ["utils/common.sh"]="$INSTALL_DIR/utils/common.sh"
        ["utils/validator.sh"]="$INSTALL_DIR/utils/validator.sh"
        ["utils/logger.sh"]="$INSTALL_DIR/utils/logger.sh"
        
        # Configuration files
        ["config/system.conf"]="$INSTALL_DIR/config/system.conf"
        ["config/vmess.json"]="$INSTALL_DIR/config/vmess.json"
        ["config/vless.json"]="$INSTALL_DIR/config/vless.json"
        ["config/trojan.json"]="$INSTALL_DIR/config/trojan.json"
        ["config/nginx.conf"]="$INSTALL_DIR/config/nginx.conf"
        ["config/outbounds.json"]="$INSTALL_DIR/config/outbounds.json"
        ["config/rules.json"]="$INSTALL_DIR/config/rules.json"
        
        # System scripts
        ["scripts/system/deps.sh"]="$INSTALL_DIR/scripts/system/deps.sh"
        ["scripts/system/optimize.sh"]="$INSTALL_DIR/scripts/system/optimize.sh"
        ["scripts/system/firewall.sh"]="$INSTALL_DIR/scripts/system/firewall.sh"
        
        # Service scripts
        ["scripts/services/ssh.sh"]="$INSTALL_DIR/scripts/services/ssh.sh"
        
        # Account management scripts
        ["scripts/accounts/ssh-account.sh"]="$INSTALL_DIR/scripts/accounts/ssh-account.sh"
        
        # Xray management scripts
        ["scripts/xray-client.sh"]="$INSTALL_DIR/scripts/xray-client.sh"
        ["scripts/xray-manager.sh"]="$INSTALL_DIR/scripts/xray-manager.sh"
        ["scripts/ssl-manager.sh"]="$INSTALL_DIR/scripts/ssl-manager.sh"
        
        # Systemd service files
        ["systemd/xray-vmess.service"]="$INSTALL_DIR/systemd/xray-vmess.service"
        ["systemd/xray-vless.service"]="$INSTALL_DIR/systemd/xray-vless.service"
        ["systemd/xray-trojan.service"]="$INSTALL_DIR/systemd/xray-trojan.service"
    )
    
    # Create systemd directory
    mkdir -p "$INSTALL_DIR/systemd"
    
    # Download all files
    local failed_downloads=()
    for remote_path in "${!files_to_download[@]}"; do
        local local_path="${files_to_download[$remote_path]}"
        local url="$REPO_URL/$remote_path"
        
        if download_file_with_retry "$url" "$local_path"; then
            # Set executable permissions for script files
            if [[ "$local_path" == *.sh ]]; then
                chmod +x "$local_path"
            fi
        else
            failed_downloads+=("$remote_path")
        fi
    done
    
    # Check if any downloads failed
    if [[ ${#failed_downloads[@]} -gt 0 ]]; then
        log_error "Failed to download the following files:"
        for file in "${failed_downloads[@]}"; do
            log_error "  - $file"
        done
        return 1
    fi
    
    # Set proper permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/config/system.conf"
    
    log_success "All autoscript files downloaded successfully"
}

# Install dependencies
install_dependencies() {
    log_section "Installing Dependencies"
    
    # Update package lists
    log_info "Updating package lists..."
    if ! apt-get update -qq; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install essential packages
    local packages=(
        "curl"
        "wget"
        "unzip"
        "jq"
        "openssl"
        "uuidgen"
        "net-tools"
        "lsof"
        "nginx"
        "ufw"
        "certbot"
        "python3-certbot-nginx"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            if apt-get install -y "$package" >/dev/null 2>&1; then
                log_success "Installed $package"
            else
                log_error "Failed to install $package"
                return 1
            fi
        else
            log_info "$package is already installed"
        fi
    done
    
    log_success "Dependencies installation completed"
}

# Install Xray-core
install_xray() {
    log_section "Installing Xray-core"
    
    # Check if Xray is already installed
    if command -v xray >/dev/null 2>&1; then
        local xray_version=$(xray version | head -n1)
        log_info "Xray is already installed: $xray_version"
        return 0
    fi
    
    # Detect system architecture
    local arch
    case $(uname -m) in
        x86_64)  arch="linux-64" ;;
        aarch64) arch="linux-arm64-v8a" ;;
        armv7l)  arch="linux-arm32-v7a" ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    # Download and install Xray
    local xray_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-${arch}.zip"
    local temp_dir="/tmp/xray_install"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log_info "Downloading Xray for $arch..."
    if wget -q "$xray_url" -O xray.zip; then
        if unzip -q xray.zip; then
            # Install Xray binary
            if cp xray /usr/local/bin/; then
                chmod +x /usr/local/bin/xray
                log_success "Xray binary installed"
            else
                log_error "Failed to install Xray binary"
                return 1
            fi
            
            # Install geoip and geosite files
            for file in geoip.dat geosite.dat; do
                if [[ -f "$file" ]]; then
                    cp "$file" /etc/xray/
                    log_info "Installed $file"
                fi
            done
        else
            log_error "Failed to extract Xray archive"
            return 1
        fi
    else
        log_error "Failed to download Xray"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    if command -v xray >/dev/null 2>&1; then
        local xray_version=$(xray version | head -n1)
        log_success "Xray installed: $xray_version"
        return 0
    else
        log_error "Xray installation verification failed"
        return 1
    fi
}

# Generate SSL certificates
generate_ssl_certificates() {
    log_section "Generating SSL Certificates"
    
    local cert_file="$SSL_DIR/cert.pem"
    local key_file="$SSL_DIR/key.pem"
    
    # Create SSL directory
    mkdir -p "$SSL_DIR"
    
    # Get server IP address
    local server_ip
    server_ip=$(curl -s --connect-timeout 10 --max-time 15 "https://ipv4.icanhazip.com" 2>/dev/null || echo "127.0.0.1")
    
    if [[ -z "$server_ip" ]]; then
        log_warning "Could not get public IP, using localhost"
        server_ip="127.0.0.1"
    fi
    
    # Generate private key
    log_info "Generating private key..."
    if openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1; then
        chmod 600 "$key_file"
        log_success "Private key generated"
    else
        log_error "Failed to generate private key"
        return 1
    fi
    
    # Generate certificate
    log_info "Generating certificate..."
    cat > /tmp/xray_cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = Modern Tunneling
OU = Autoscript
CN = ${server_ip}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ${server_ip}
IP.1 = ${server_ip}
IP.2 = 127.0.0.1
EOF
    
    if openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 3650 \
        -config /tmp/xray_cert.conf -extensions v3_req >/dev/null 2>&1; then
        chmod 644 "$cert_file"
        rm -f /tmp/xray_cert.conf
        log_success "Certificate generated (valid for 10 years)"
        return 0
    else
        log_error "Failed to generate certificate"
        rm -f /tmp/xray_cert.conf
        return 1
    fi
}

# Setup Xray services
setup_xray_services() {
    log_section "Setting Up Xray Services"
    
    # Copy configuration files
    log_info "Installing Xray configuration files..."
    cp "$INSTALL_DIR/config/vmess.json" "$XRAY_CONFIG_DIR/vmess.json"
    cp "$INSTALL_DIR/config/vless.json" "$XRAY_CONFIG_DIR/vless.json"
    cp "$INSTALL_DIR/config/trojan.json" "$XRAY_CONFIG_DIR/trojan.json"
    cp "$INSTALL_DIR/config/outbounds.json" "$XRAY_CONFIG_DIR/outbounds.json"
    cp "$INSTALL_DIR/config/rules.json" "$XRAY_CONFIG_DIR/rules.json"
    
    # Set proper permissions
    chmod 644 "$XRAY_CONFIG_DIR"/*.json
    chown root:root "$XRAY_CONFIG_DIR"/*.json
    
    # Install systemd service files
    log_info "Installing systemd service files..."
    cp "$INSTALL_DIR/systemd/xray-vmess.service" "/etc/systemd/system/"
    cp "$INSTALL_DIR/systemd/xray-vless.service" "/etc/systemd/system/"
    cp "$INSTALL_DIR/systemd/xray-trojan.service" "/etc/systemd/system/"
    
    # Set proper permissions for service files
    chmod 644 /etc/systemd/system/xray-*.service
    
    # Reload systemd and enable services
    systemctl daemon-reload
    
    # Enable services (but don't start them yet)
    systemctl enable xray-vmess.service
    systemctl enable xray-vless.service  
    systemctl enable xray-trojan.service
    
    log_success "Xray-core services configured successfully"
}

# Setup nginx
setup_nginx() {
    log_section "Setting Up Nginx"
    
    # Backup default nginx config
    if [[ -f /etc/nginx/sites-available/default ]]; then
        mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    fi
    
    # Install our nginx configuration
    cp "$INSTALL_DIR/config/nginx.conf" /etc/nginx/sites-available/default
    
    # Test nginx configuration
    if nginx -t >/dev/null 2>&1; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration is invalid"
        # Restore backup
        if [[ -f /etc/nginx/sites-available/default.backup ]]; then
            mv /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
        fi
        return 1
    fi
    
    # Enable and start nginx
    systemctl enable nginx
    systemctl restart nginx
    
    log_success "Nginx configured successfully"
}

# Setup firewall
setup_firewall() {
    log_section "Configuring Firewall"
    
    # Install UFW if not present
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get install -y ufw
    fi
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH ports
    ufw allow 22/tcp
    ufw allow 2222/tcp
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8443/tcp
    
    # Allow Xray ports
    ufw allow 55/tcp
    ufw allow 58/tcp
    ufw allow 1054/tcp
    ufw allow 1055/tcp
    ufw allow 1057/tcp
    ufw allow 1058/tcp
    ufw allow 1059/tcp
    ufw allow 1060/tcp
    ufw allow 1061/tcp
    
    # Enable UFW
    ufw --force enable
    
    log_success "Firewall configured successfully"
}

# Run system optimization
run_system_optimization() {
    log_section "Running System Optimization"
    
    # Basic system optimizations
    log_info "Applying system optimizations..."
    
    # Optimize kernel parameters
    cat >> /etc/sysctl.conf << EOF

# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq
EOF
    
    # Apply sysctl changes
    sysctl -p >/dev/null 2>&1 || true
    
    # Optimize limits
    cat >> /etc/security/limits.conf << EOF

# Increase file descriptor limits
* soft nofile 65536
* hard nofile 65536
EOF
    
    log_success "System optimization completed"
}

# Create management scripts
create_management_scripts() {
    log_section "Creating Management Scripts"
    
    # Create Xray management script
    cat > "$BIN_DIR/xray-mgmt" << 'EOF'
#!/bin/bash

case "$1" in
    start)
        systemctl start xray-vmess xray-vless xray-trojan
        echo "Xray services started"
        ;;
    stop)
        systemctl stop xray-vmess xray-vless xray-trojan
        echo "Xray services stopped"
        ;;
    restart)
        systemctl restart xray-vmess xray-vless xray-trojan
        echo "Xray services restarted"
        ;;
    status)
        echo "VMess Service:"
        systemctl status xray-vmess --no-pager -l
        echo ""
        echo "VLESS Service:"
        systemctl status xray-vless --no-pager -l  
        echo ""
        echo "Trojan Service:"
        systemctl status xray-trojan --no-pager -l
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BIN_DIR/xray-mgmt"
    
    # Install Xray client management script
    if [[ -f "$INSTALL_DIR/scripts/xray-client.sh" ]]; then
        cp "$INSTALL_DIR/scripts/xray-client.sh" "$BIN_DIR/xray-client"
        chmod +x "$BIN_DIR/xray-client"
        log_info "Xray client management script installed"
    fi
    
    # Create general autoscript management script
    cat > "$BIN_DIR/autoscript-mgmt" << 'EOF'
#!/bin/bash

case "$1" in
    start)
        systemctl start ssh dropbear xray-vmess xray-vless xray-trojan nginx
        echo "All services started"
        ;;
    stop)
        systemctl stop ssh dropbear xray-vmess xray-vless xray-trojan nginx
        echo "All services stopped"
        ;;
    restart)
        systemctl restart ssh dropbear xray-vmess xray-vless xray-trojan nginx
        echo "All services restarted"
        ;;
    status)
        echo "=== Service Status ==="
        for service in ssh dropbear xray-vmess xray-vless xray-trojan nginx; do
            if systemctl is-active --quiet "$service"; then
                echo "$service: RUNNING"
            else
                echo "$service: STOPPED"
            fi
        done
        ;;
    health)
        echo "=== Health Check ==="
        for service in ssh dropbear xray-vmess xray-vless xray-trojan nginx; do
            if systemctl is-active --quiet "$service"; then
                echo "✓ $service: RUNNING"
            else
                echo "✗ $service: STOPPED"
            fi
        done
        
        echo ""
        echo "=== Port Status ==="
        for port in 22 80 443 55 58; do
            if ss -tuln | grep -q ":$port "; then
                echo "✓ Port $port: LISTENING"
            else
                echo "✗ Port $port: NOT LISTENING"
            fi
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|health}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BIN_DIR/autoscript-mgmt"
    
    log_success "Management scripts created successfully"
}

# Start services
start_services() {
    log_section "Starting Services"
    
    # Start Xray services
    log_info "Starting Xray services..."
    systemctl start xray-vmess.service
    systemctl start xray-vless.service
    systemctl start xray-trojan.service
    
    # Wait for services to be ready
    sleep 3
    
    # Check service status
    local failed_services=()
    for service in xray-vmess xray-vless xray-trojan nginx; do
        if systemctl is-active --quiet "$service"; then
            log_success "Service $service is running"
        else
            log_warning "Service $service failed to start"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warning "Some services failed to start. Please check manually:"
        for service in "${failed_services[@]}"; do
            log_warning "  systemctl status $service"
        done
    else
        log_success "All services started successfully"
    fi
}

# Validate installation
validate_installation() {
    log_section "Validating Installation"
    
    local validation_passed=true
    
    # Check if required files exist
    local required_files=(
        "/etc/xray/vmess.json"
        "/etc/xray/vless.json"
        "/etc/xray/trojan.json"
        "/etc/xray/ssl/cert.pem"
        "/etc/xray/ssl/key.pem"
        "/usr/local/bin/xray-mgmt"
        "/usr/local/bin/autoscript-mgmt"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "File exists: $file"
        else
            log_error "File missing: $file"
            validation_passed=false
        fi
    done
    
    # Validate JSON configurations
    local json_files=(
        "/etc/xray/vmess.json"
        "/etc/xray/vless.json"
        "/etc/xray/trojan.json"
    )
    
    for file in "${json_files[@]}"; do
        if jq . "$file" >/dev/null 2>&1; then
            log_success "Valid JSON: $file"
        else
            log_error "Invalid JSON: $file"
            validation_passed=false
        fi
    done
    
    # Test Xray configurations
    for file in "${json_files[@]}"; do
        if xray run -test -config "$file" >/dev/null 2>&1; then
            log_success "Valid Xray config: $file"
        else
            log_error "Invalid Xray config: $file"
            validation_passed=false
        fi
    done
    
    # Test Nginx configuration
    if nginx -t >/dev/null 2>&1; then
        log_success "Valid Nginx configuration"
    else
        log_error "Invalid Nginx configuration"
        validation_passed=false
    fi
    
    # Check SSL certificate
    if openssl x509 -in /etc/xray/ssl/cert.pem -noout -text >/dev/null 2>&1; then
        log_success "Valid SSL certificate"
    else
        log_error "Invalid SSL certificate"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Installation validation passed"
        return 0
    else
        log_error "Installation validation failed"
        return 1
    fi
}

# Display installation summary
display_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    
    echo ""
    echo "=============================================================="
    echo "                  INSTALLATION COMPLETED"
    echo "=============================================================="
    echo ""
    echo "Modern Tunneling Autoinstaller v4.0.0"
    echo "Installation completed in ${duration} seconds"
    echo ""
    echo "Services installed:"
    echo "  • SSH (port 22)"
    echo "  • Dropbear SSH (port 2222)"
    echo "  • Xray VMess (WebSocket: port 55, gRPC: port 1054, TCP: port 1055)"
    echo "  • Xray VLESS (WebSocket: port 58, gRPC: port 1057, TCP: port 1058)"
    echo "  • Xray Trojan (WebSocket: port 1060, gRPC: port 1061, TCP: port 1059)"
    echo "  • Nginx (HTTP: port 80, HTTPS: port 443, gRPC: port 8443)"
    echo ""
    echo "Management commands:"
    echo "  • autoscript-mgmt {start|stop|restart|status|health}"
    echo "  • xray-mgmt {start|stop|restart|status}"
    echo "  • xray-client {add|remove|list|config} - Manage Xray clients"
    echo ""
    echo "Configuration files:"
    echo "  • Xray configs: /etc/xray/"
    echo "  • Nginx config: /etc/nginx/sites-available/default"
    echo "  • SSL certificates: /etc/xray/ssl/"
    echo ""
    echo "Log files:"
    echo "  • Installation log: $LOG_FILE"
    echo "  • Error log: $ERROR_LOG"
    echo "  • System logs: /var/log/autoscript/"
    echo "  • Xray logs: /var/log/xray/"
    echo ""
    echo "Next steps:"
    echo "1. Start services: autoscript-mgmt start"
    echo "2. Check health: autoscript-mgmt health"
    echo "3. Add clients: xray-client add vmess username"
    echo "4. List clients: xray-client list"
    echo ""
    echo "=============================================================="
}

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

main() {
    # Set up error handling
    trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$ERROR_LOG")"
    
    echo "=============================================================="
    echo "               Modern Tunneling Autoinstaller"
    echo "                    Version 4.0.0"
    echo ""
    echo "  Production-ready tunneling solution with:"
    echo "  • SSH & Dropbear SSH"
    echo "  • Xray-core (VMess, VLESS, Trojan) - Separated Services"
    echo "  • WebSocket tunneling with Nginx"
    echo "  • Advanced account management"
    echo "  • System optimization"
    echo "  • Comprehensive error handling"
    echo ""
    echo "  Compatible: Debian 11+ | Ubuntu 22.04+"
    echo "  Installation: One-command via curl"
    echo "=============================================================="
    
    log_info "Starting installation process..."
    
    # Pre-installation checks
    check_root
    check_system_compatibility
    check_internet
    check_disk_space
    
    # Installation steps
    create_directory_structure
    download_autoscript_files
    install_dependencies
    install_xray
    setup_xray_services
    setup_nginx
    generate_ssl_certificates
    setup_firewall
    run_system_optimization
    create_management_scripts
    start_services
    
    # Post-installation validation
    validate_installation
    
    # Mark installation as successful
    INSTALLATION_SUCCESS=true
    
    # Display summary
    display_summary
    
    log_success "Installation completed successfully!"
    
    # Cleanup on success
    if [[ "$INSTALLATION_SUCCESS" == "true" ]]; then
        log_info "Installation completed successfully. Cleaning up temporary files..."
        rm -rf /tmp/xray_install 2>/dev/null || true
        rm -f /tmp/xray_cert.conf 2>/dev/null || true
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Show usage
show_usage() {
    echo "Modern Tunneling Autoinstaller v4.0.0"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install                  - Complete installation (default)"
    echo "  status                   - Show service status"
    echo "  health                   - Show health check"
    echo "  info                     - Show installation information"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 status"
    echo "  $0 health"
    echo ""
    echo "Quick Install:"
    echo "  curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/autoinstaller.sh | bash"
}

# Parse command line arguments
case "${1:-install}" in
    "install")
        main
        ;;
    "status")
        if [[ -x "$BIN_DIR/autoscript-mgmt" ]]; then
            "$BIN_DIR/autoscript-mgmt" status
        else
            echo "Error: Management script not found. Please run installation first."
            exit 1
        fi
        ;;
    "health")
        if [[ -x "$BIN_DIR/autoscript-mgmt" ]]; then
            "$BIN_DIR/autoscript-mgmt" health
        else
            echo "Error: Management script not found. Please run installation first."
            exit 1
        fi
        ;;
    "info")
        echo "Modern Tunneling Autoinstaller v4.0.0"
        echo "Installation directory: $INSTALL_DIR"
        echo "Configuration directory: $CONFIG_DIR"
        echo "Xray configuration: $XRAY_CONFIG_DIR"
        echo "SSL certificates: $SSL_DIR"
        echo "Management scripts: $BIN_DIR"
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_usage
        exit 1
        ;;
esac