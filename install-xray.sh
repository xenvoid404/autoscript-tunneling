#!/bin/bash

# Xray Installation Script
# Complete setup for Xray with new service names and separate JSON files

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
if [[ -f "$SCRIPT_DIR/utils/common.sh" ]]; then
    source "$SCRIPT_DIR/utils/common.sh"
else
    echo "Error: Common utilities not found"
    exit 1
fi

# Check if running as root
check_root

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    
    local packages=(
        "curl"
        "wget"
        "unzip"
        "jq"
        "openssl"
        "uuidgen"
        "net-tools"
        "lsof"
    )
    
    for package in "${packages[@]}"; do
        if ! command_exists "$package"; then
            print_info "Installing $package..."
            if apt-get install -y "$package" &>/dev/null; then
                print_success "Installed $package"
            else
                print_error "Failed to install $package"
                return 1
            fi
        else
            print_info "$package is already installed"
        fi
    done
    
    print_success "Dependencies installation completed"
    return 0
}

# Function to install Xray
install_xray() {
    echo "Installing Xray..."
    
    # Create Xray directories
    mkdir -p /usr/local/bin
    mkdir -p /etc/xray
    mkdir -p /var/log/xray
    
    # Detect system architecture
    local arch
    case $(uname -m) in
        x86_64)  arch="linux-64" ;;
        aarch64) arch="linux-arm64-v8a" ;;
        armv7l)  arch="linux-arm32-v7a" ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    # Download Xray
    local xray_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-${arch}.zip"
    local temp_dir="/tmp/xray_install"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    print_info "Downloading Xray for $arch..."
    if wget -q "$xray_url" -O xray.zip; then
        if unzip -q xray.zip; then
            # Install Xray binary
            if cp xray /usr/local/bin/; then
                chmod +x /usr/local/bin/xray
                print_success "Xray binary installed"
            else
                print_error "Failed to install Xray binary"
                return 1
            fi
            
            # Install geoip and geosite files
            for file in geoip.dat geosite.dat; do
                if [[ -f "$file" ]]; then
                    cp "$file" /etc/xray/
                    print_info "Installed $file"
                fi
            done
        else
            print_error "Failed to extract Xray archive"
            return 1
        fi
    else
        print_error "Failed to download Xray"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    if command_exists xray; then
        local xray_version=$(xray version | head -n1)
        print_success "Xray installed: $xray_version"
    else
        print_error "Xray installation verification failed"
        return 1
    fi
    
    return 0
}

# Function to setup SSL certificates
setup_ssl() {
    echo "Setting up SSL certificates..."
    
    if [[ -f "$SCRIPT_DIR/scripts/ssl-manager.sh" ]]; then
        if "$SCRIPT_DIR/scripts/ssl-manager.sh" setup; then
            print_success "SSL setup completed"
            return 0
        else
            print_error "SSL setup failed"
            return 1
        fi
    else
        print_error "SSL manager script not found"
        return 1
    fi
}

# Function to setup Xray services
setup_xray_services() {
    echo "Setting up Xray services..."
    
    if [[ -f "$SCRIPT_DIR/scripts/xray-manager.sh" ]]; then
        if "$SCRIPT_DIR/scripts/xray-manager.sh" setup; then
            print_success "Xray services setup completed"
            return 0
        else
            print_error "Xray services setup failed"
            return 1
        fi
    else
        print_error "Xray manager script not found"
        return 1
    fi
}

# Function to validate configurations
validate_configurations() {
    echo "Validating Xray configurations..."
    
    if [[ -f "$SCRIPT_DIR/scripts/xray-manager.sh" ]]; then
        if "$SCRIPT_DIR/scripts/xray-manager.sh" validate all; then
            print_success "All configurations are valid"
            return 0
        else
            print_error "Configuration validation failed"
            return 1
        fi
    else
        print_error "Xray manager script not found"
        return 1
    fi
}

# Function to start services
start_services() {
    echo "Starting Xray services..."
    
    if [[ -f "$SCRIPT_DIR/scripts/xray-manager.sh" ]]; then
        if "$SCRIPT_DIR/scripts/xray-manager.sh" start all; then
            print_success "All services started"
            return 0
        else
            print_error "Failed to start services"
            return 1
        fi
    else
        print_error "Xray manager script not found"
        return 1
    fi
}

# Function to show service status
show_status() {
    echo "Checking service status..."
    
    if [[ -f "$SCRIPT_DIR/scripts/xray-manager.sh" ]]; then
        "$SCRIPT_DIR/scripts/xray-manager.sh" status all
    else
        print_error "Xray manager script not found"
        return 1
    fi
}

# Function to show installation information
show_info() {
    echo ""
    echo "Xray Installation Information"
    echo "============================"
    echo ""
    echo "Service Names:"
    echo "- VMess: spectrum.service"
    echo "- VLESS: quantix.service"
    echo "- Trojan: cipheron.service"
    echo ""
    echo "Configuration Files:"
    echo "- VMess: /etc/xray/vmess.json"
    echo "- VLESS: /etc/xray/vless.json"
    echo "- Trojan: /etc/xray/trojan.json"
    echo "- Outbounds: /etc/xray/outbounds.json"
    echo "- Rules: /etc/xray/rules.json"
    echo ""
    echo "SSL Certificates:"
    echo "- Certificate: /etc/xray/ssl/cert.pem"
    echo "- Private Key: /etc/xray/ssl/key.pem"
    echo ""
    echo "Management Commands:"
    echo "- Service management: $SCRIPT_DIR/scripts/xray-manager.sh"
    echo "- SSL management: $SCRIPT_DIR/scripts/ssl-manager.sh"
    echo "- Client management: $SCRIPT_DIR/scripts/xray-client.sh"
    echo ""
    echo "Example Commands:"
    echo "- Start spectrum service: $SCRIPT_DIR/scripts/xray-manager.sh start spectrum"
    echo "- Check all services: $SCRIPT_DIR/scripts/xray-manager.sh status all"
    echo "- Validate configurations: $SCRIPT_DIR/scripts/xray-manager.sh validate all"
    echo "- Generate SSL certificate: $SCRIPT_DIR/scripts/ssl-manager.sh generate"
    echo ""
}

# Main installation function
main() {
    print_banner
    print_section "Xray Installation"
    
    # Check system compatibility
    check_compatibility
    
    # Check internet connectivity
    if ! check_internet; then
        print_error "Internet connectivity required for installation"
        exit 1
    fi
    
    # Update package lists
    print_info "Updating package lists..."
    apt-get update &>/dev/null
    
    # Install dependencies
    if ! install_dependencies; then
        print_error "Dependencies installation failed"
        exit 1
    fi
    
    # Install Xray
    if ! install_xray; then
        print_error "Xray installation failed"
        exit 1
    fi
    
    # Setup SSL certificates
    if ! setup_ssl; then
        print_error "SSL setup failed"
        exit 1
    fi
    
    # Setup Xray services
    if ! setup_xray_services; then
        print_error "Xray services setup failed"
        exit 1
    fi
    
    # Validate configurations
    if ! validate_configurations; then
        print_error "Configuration validation failed"
        exit 1
    fi
    
    # Start services
    if ! start_services; then
        print_error "Failed to start services"
        exit 1
    fi
    
    # Show status
    show_status
    
    # Show installation information
    show_info
    
    print_success "Xray installation completed successfully!"
    print_info "All services are now running with the new naming convention"
}

# Show usage
show_usage() {
    echo "Xray Installation Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install                  - Complete installation (default)"
    echo "  status                   - Show service status"
    echo "  info                     - Show installation information"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 status"
    echo "  $0 info"
}

# Parse command line arguments
case "${1:-install}" in
    "install")
        main
        ;;
    "status")
        show_status
        ;;
    "info")
        show_info
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_usage
        exit 1
        ;;
esac