#!/bin/bash

# Yuipedia Tunneling - Main Installer
# Production-ready tunneling solution for Debian 11+ and Ubuntu 22.04+
# 
# Author: Yuipedia
# Version: 3.0.0
# License: MIT
#
# Quick Install:
# curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh | bash

set -e

# Installation directories
readonly INSTALL_DIR="/opt/autoscript"
readonly CONFIG_DIR="/etc/autoscript"
readonly BIN_DIR="/usr/local/bin"
readonly LOG_DIR="/var/log/autoscript"
readonly XRAY_CONFIG_DIR="/etc/xray"

# GitHub repository configuration
readonly GITHUB_USER="xenvoid404"
readonly GITHUB_REPO="autoscript-tunneling"
readonly GITHUB_BRANCH="master"
readonly REPO_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Source common utilities
source_utilities() {
    if [[ -f "$INSTALL_DIR/utils/common.sh" ]]; then
        source "$INSTALL_DIR/utils/common.sh"
    else
        echo "Error: Common utilities not found"
        exit 1
    fi
}

# Print banner
print_banner() {
    clear
    echo "=============================================================="
    echo "               Modern Tunneling Autoscript"
    echo "                    Version 3.0.0"
    echo ""
    echo "  Production-ready tunneling solution with:"
    echo "  • SSH & Dropbear SSH"
    echo "  • Xray-core (VMess, VLESS, Trojan) - Separated Services"
    echo "  • WebSocket tunneling with Nginx"
    echo "  • Advanced account management"
    echo "  • System optimization"
    echo ""
    echo "  Compatible: Debian 11+ | Ubuntu 22.04+"
    echo "  Installation: One-command via curl"
    echo "=============================================================="
}

# System compatibility check
check_system_compatibility() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    # Get OS information
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo "Error: Cannot detect OS information"
        exit 1
    fi
    
    # Function to compare version numbers
    version_compare() {
        local version1=$1
        local operator=$2  
        local version2=$3
        
        # Convert versions to comparable format (handle major.minor)
        local v1_major=$(echo "$version1" | cut -d. -f1)
        local v1_minor=$(echo "$version1" | cut -d. -f2 2>/dev/null || echo "0")
        local v2_major=$(echo "$version2" | cut -d. -f1)
        local v2_minor=$(echo "$version2" | cut -d. -f2 2>/dev/null || echo "0")
        
        # Handle fractional parts properly
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
                echo "Error: Ubuntu 22.04+ required. Current: $VER"
                exit 1
            fi
            ;;
        "Debian GNU/Linux")
            if ! version_compare "$VER" ">=" "11"; then
                echo "Error: Debian 11+ required. Current: $VER"
                exit 1
            fi
            ;;
        *)
            echo "Error: Unsupported OS: $OS"
            echo "Supported: Ubuntu 22.04+ or Debian 11+"
            exit 1
            ;;
    esac
    
    echo "System compatibility check passed: $OS $VER"
}

# Check internet connectivity
check_internet() {
    echo "Checking internet connectivity..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "Internet connectivity: OK"
        return 0
    else
        echo "Error: No internet connectivity detected"
        return 1
    fi
}

# Create directory structure
create_directory_structure() {
    echo "Creating directory structure..."
    
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
        "/var/lib/autoscript"
        "/usr/local/bin/autoscript-mgmt"
        "/usr/local/bin/xray-mgmt"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir" && chmod 755 "$dir"; then
            echo "Created directory: $dir"
        else
            echo "Error: Failed to create directory: $dir"
            exit 1
        fi
    done
    echo "Directory structure created successfully"
}

# Download file with retry mechanism
download_file_with_retry() {
    local url="$1"
    local destination="$2"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        echo "Downloading $(basename "$destination") (attempt $attempt/$max_attempts)..."
        
        if wget -q --show-progress --timeout=30 --tries=2 -O "$destination" "$url"; then
            echo "Downloaded: $(basename "$destination")"
            return 0
        else
            echo "Download attempt $attempt failed"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 2
            fi
        fi
    done
    
    echo "Error: Failed to download after $max_attempts attempts: $url"
    return 1
}

# Download and install autoscript files from GitHub
download_autoscript_files() {
    echo "Downloading Autoscript Files from GitHub..."
    
    # Define files to download with their destinations
    declare -A files_to_download=(
        # Utility files
        ["utils/common.sh"]="$INSTALL_DIR/utils/common.sh"
        ["utils/validator.sh"]="$INSTALL_DIR/utils/validator.sh"
        
        # Configuration files
        ["config/system.conf"]="$INSTALL_DIR/config/system.conf"
        ["config/vmess.json"]="$INSTALL_DIR/config/vmess.json"
        ["config/vless.json"]="$INSTALL_DIR/config/vless.json"
        ["config/trojan.json"]="$INSTALL_DIR/config/trojan.json"
        ["config/nginx.conf"]="$INSTALL_DIR/config/nginx.conf"
        
        # System scripts
        ["scripts/system/deps.sh"]="$INSTALL_DIR/scripts/system/deps.sh"
        ["scripts/system/optimize.sh"]="$INSTALL_DIR/scripts/system/optimize.sh"
        ["scripts/system/firewall.sh"]="$INSTALL_DIR/scripts/system/firewall.sh"
        
        # Service scripts
        ["scripts/services/ssh.sh"]="$INSTALL_DIR/scripts/services/ssh.sh"
        
        # Account management scripts
        ["scripts/accounts/ssh-account.sh"]="$INSTALL_DIR/scripts/accounts/ssh-account.sh"
        
        # Xray client management script
        ["scripts/xray-client.sh"]="$INSTALL_DIR/scripts/xray-client.sh"
        
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
        echo "Error: Failed to download the following files:"
        for file in "${failed_downloads[@]}"; do
            echo "  - $file"
        done
        echo "Please check your internet connection and GitHub repository access"
        exit 1
    fi
    
    # Set proper permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/config/system.conf"
    
    echo "All autoscript files downloaded successfully"
}

# Test GitHub connectivity
test_github_connectivity() {
    echo "Testing GitHub connectivity..."
    
    local test_url="$REPO_URL/README.md"
    if wget -q --spider --timeout=10 "$test_url"; then
        echo "GitHub repository accessible"
        return 0
    else
        echo "Error: Cannot access GitHub repository"
        echo "Repository: $REPO_URL"
        echo "Please check:"
        echo "1. Internet connectivity"
        echo "2. GitHub repository exists and is public"
        echo "3. Repository URL is correct"
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    echo "Installing Service Dependencies..."
    
    if [[ -f "$INSTALL_DIR/scripts/system/deps.sh" ]]; then
        echo "Running dependency installation script..."
        bash "$INSTALL_DIR/scripts/system/deps.sh" || {
            echo "Error: Dependency installation failed"
            exit 1
        }
        echo "Dependencies installed successfully"
    else
        echo "Error: Dependency installation script not found"
        exit 1
    fi
}

# Setup SSH services
setup_ssh_services() {
    echo "Setting Up SSH Services..."
    
    if [[ -f "$INSTALL_DIR/scripts/services/ssh.sh" ]]; then
        echo "Configuring SSH and Dropbear services..."
        bash "$INSTALL_DIR/scripts/services/ssh.sh" || {
            echo "Error: SSH services configuration failed"
            exit 1
        }
        echo "SSH services configured successfully"
    else
        echo "Error: SSH setup script not found"
        exit 1
    fi
}

# Setup separated Xray services
setup_xray_services() {
    echo "Setting Up Xray-core Services (Separated)..."
    
    # Install Xray-core if not present
    if ! command -v xray >/dev/null 2>&1; then
        echo "Installing Xray-core..."
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi
    
    # Copy configuration files
    echo "Installing Xray configuration files..."
    cp "$INSTALL_DIR/config/vmess.json" "$XRAY_CONFIG_DIR/vmess.json"
    cp "$INSTALL_DIR/config/vless.json" "$XRAY_CONFIG_DIR/vless.json"
    cp "$INSTALL_DIR/config/trojan.json" "$XRAY_CONFIG_DIR/trojan.json"
    
    # Set proper permissions
    chmod 644 "$XRAY_CONFIG_DIR"/*.json
    chown root:root "$XRAY_CONFIG_DIR"/*.json
    
    # Install systemd service files
    echo "Installing systemd service files..."
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
    
    echo "Xray-core services configured successfully"
}

# Setup nginx
setup_nginx() {
    echo "Setting Up Nginx..."
    
    # Install nginx if not present
    if ! command -v nginx >/dev/null 2>&1; then
        echo "Installing Nginx..."
        apt-get update
        apt-get install -y nginx
    fi
    
    # Backup default nginx config
    if [[ -f /etc/nginx/sites-available/default ]]; then
        mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    fi
    
    # Install our nginx configuration
    cp "$INSTALL_DIR/config/nginx.conf" /etc/nginx/sites-available/default
    
    # Test nginx configuration
    if nginx -t; then
        echo "Nginx configuration is valid"
    else
        echo "Error: Nginx configuration is invalid"
        # Restore backup
        if [[ -f /etc/nginx/sites-available/default.backup ]]; then
            mv /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
        fi
        exit 1
    fi
    
    # Enable and start nginx
    systemctl enable nginx
    systemctl restart nginx
    
    echo "Nginx configured successfully"
}

# Generate SSL certificates
generate_ssl_certificates() {
    echo "Generating SSL Certificates..."
    
    local cert_dir="$XRAY_CONFIG_DIR"
    local cert_file="$cert_dir/xray.crt"
    local key_file="$cert_dir/xray.key"
    
    # Get server IP address
    local server_ip
    server_ip=$(curl -s --connect-timeout 10 --max-time 15 "https://ipv4.icanhazip.com" 2>/dev/null || echo "127.0.0.1")
    
    if [[ -z "$server_ip" ]]; then
        echo "Could not get public IP, using localhost"
        server_ip="127.0.0.1"
    fi
    
    # Generate private key
    echo "Generating private key..."
    if openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1; then
        chmod 600 "$key_file"
        echo "Private key generated"
    else
        echo "Error: Failed to generate private key"
        return 1
    fi
    
    # Generate certificate
    echo "Generating certificate..."
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
        echo "Certificate generated (valid for 10 years)"
    else
        echo "Error: Failed to generate certificate"
        rm -f /tmp/xray_cert.conf
        return 1
    fi
    
    return 0
}

# Setup firewall
setup_firewall() {
    echo "Configuring Firewall..."
    
    if [[ -f "$INSTALL_DIR/scripts/system/firewall.sh" ]]; then
        echo "Running firewall configuration script..."
        bash "$INSTALL_DIR/scripts/system/firewall.sh" || echo "Warning: Firewall configuration had issues"
    else
        echo "Installing and configuring UFW firewall manually..."
        
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
        
        # Enable UFW
        ufw --force enable
    fi
    
    echo "Firewall configured successfully"
}

# Run system optimization
run_system_optimization() {
    echo "Running System Optimization..."
    
    if [[ -f "$INSTALL_DIR/scripts/system/optimize.sh" ]]; then
        echo "Running system optimization script..."
        bash "$INSTALL_DIR/scripts/system/optimize.sh" || echo "Warning: System optimization had some issues"
        echo "System optimization completed"
    else
        echo "Error: System optimization script not found"
        exit 1
    fi
}

# Start services
start_services() {
    echo "Starting Services..."
    
    # Start Xray services
    echo "Starting Xray services..."
    systemctl start xray-vmess.service
    systemctl start xray-vless.service
    systemctl start xray-trojan.service
    
    # Wait for services to be ready
    sleep 3
    
    # Check service status
    local failed_services=()
    for service in xray-vmess xray-vless xray-trojan nginx; do
        if systemctl is-active --quiet "$service"; then
            echo "Service $service is running"
        else
            echo "Warning: Service $service failed to start"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        echo "Some services failed to start. Please check manually:"
        for service in "${failed_services[@]}"; do
            echo "  systemctl status $service"
        done
    else
        echo "All services started successfully"
    fi
}

# Create management scripts
create_management_scripts() {
    echo "Creating management scripts..."
    
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
        echo "Xray client management script installed"
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
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BIN_DIR/autoscript-mgmt"
    
    echo "Management scripts created successfully"
}

# Display installation summary
display_summary() {
    echo ""
    echo "=============================================================="
    echo "                  INSTALLATION COMPLETED"
    echo "=============================================================="
    echo ""
    echo "Autoscript Tunneling v3.0.0 has been installed successfully!"
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
    echo "  • autoscript-mgmt {start|stop|restart|status}"
    echo "  • xray-mgmt {start|stop|restart|status}"
    echo "  • xray-client {add|remove|list|config} - Manage Xray clients"
    echo ""
    echo "Configuration files:"
    echo "  • Xray configs: /etc/xray/"
    echo "  • Nginx config: /etc/nginx/sites-available/default"
    echo "  • SSL certificates: /etc/xray/xray.{crt,key}"
    echo ""
    echo "Log files:"
    echo "  • System logs: /var/log/autoscript/"
    echo "  • Xray logs: /var/log/xray/"
    echo ""
    echo "=============================================================="
}

# Main installation function
main() {
    print_banner
    
    echo "Starting installation process..."
    
    # Pre-installation checks
    check_system_compatibility
    check_internet
    test_github_connectivity
    
    # Create directory structure
    create_directory_structure
    
    # Download files
    download_autoscript_files
    
    # Source utilities after download
    source_utilities
    
    # Install dependencies
    install_dependencies
    
    # Setup services
    setup_ssh_services
    setup_xray_services
    setup_nginx
    
    # Generate SSL certificates
    generate_ssl_certificates
    
    # Configure firewall
    setup_firewall
    
    # Run system optimization
    run_system_optimization
    
    # Create management scripts
    create_management_scripts
    
    # Start services
    start_services
    
    # Display summary
    display_summary
    
    echo "Installation completed successfully!"
}

# Run main function
main "$@"