#!/bin/bash

# Improved Autoscript Tunneling Installer
# Author: Xenvoid404
# Version: 2.0

# Load common functions
source lib/common.sh

# Load environment configuration
source config/environment.conf

# Global variables
DOMAIN=""
IP=$(curl -s ifconfig.me)

# Function to check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
}

# Function to check virtualization
check_virt() {
    if [[ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]] || grep -q openvz /proc/user_beancounters; then
        print_error "ERROR: OpenVZ tidak didukung"
        exit 1
    fi
}

# Function to check internet connection
check_internet() {
    print_info "Mengecek koneksi internet..."
    
    if ping -c 1 google.com >/dev/null 2>&1 || ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Koneksi internet tersedia"
        return 0
    else
        print_error "Tidak ada koneksi internet"
        print_info "Pastikan server terhubung ke internet untuk download script"
        exit 1
    fi
}

# Function to check OS compatibility
check_os() {
    print_info "Mengecek sistem operasi..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        VERSION_MAJOR=$(echo "$VERSION" | cut -d'.' -f1)
    else
        print_error "Operating System tidak terdeteksi"
        exit 1
    fi

    case "$OS" in
        "ubuntu")
            if [[ "$VERSION_MAJOR" -ge 22 ]]; then
                print_success "Sistem operasi didukung: Ubuntu $VERSION"
            else
                print_error "Versi Ubuntu tidak didukung! Minimal Ubuntu 22+"
                exit 1
            fi
            ;;
        "debian")
            if [[ "$VERSION_MAJOR" -ge 11 ]]; then
                print_success "Sistem operasi didukung: Debian $VERSION"
            else
                print_error "Versi Debian tidak didukung! Minimal Debian 11+"
                exit 1
            fi
            ;;
        *)
            print_error "Sistem operasi tidak didukung: $OS"
            print_info "Script ini hanya untuk Ubuntu 22+ dan Debian 11+"
            exit 1
            ;;
    esac
}

# Function to setup initial environment
first_setup() {
    print_info "Setup Environment for First Installation..."
    
    # Set timezone
    timedatectl set-timezone "$TIMEZONE"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Setup SSH configuration
    if ! download_file "${GITHUB_RAW_REPO}/ssh/sshd_config" "/etc/ssh/sshd_config"; then
        print_error "Failed to download SSH configuration"
        return 1
    fi
    chmod 644 /etc/ssh/sshd_config
    
    # Setup common-password
    if ! download_file "${GITHUB_RAW_REPO}/ssh/common-password" "/etc/pam.d/common-password"; then
        print_error "Failed to download common-password"
        return 1
    fi
    chmod 644 /etc/pam.d/common-password
    
    # Setup Banner SSH
    if ! download_file "${GITHUB_RAW_REPO}/ssh/banner.com" "/etc/banner.com"; then
        print_error "Failed to download SSH banner"
        return 1
    fi
    chmod 600 /etc/banner.com
    
    # Setup Neofetch
    if ! download_file "${GITHUB_RAW_REPO}/bin/neofetch" "/usr/local/bin/neofetch"; then
        print_error "Failed to download neofetch"
        return 1
    fi
    chmod +x /usr/local/bin/neofetch
    
    # Setup profile
    cat > /root/.profile <<-END
~/.profile: executed by Bourne-compatible login shells.
if [ "\$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi

mesg n || true
ln -fs /usr/share/zoneinfo/$TIMEZONE /etc/localtime
neofetch
\$WEB_SERVER
END

    # Setup iptables persistence
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    
    return 0
}

# Function to setup dependencies
setup_dependencies() {
    print_info "INSTALLING REQUIRED DEPENDENCIES..."
    
    # Remove unwanted packages
    apt remove --purge -y "${PACKAGES_TO_REMOVE[@]}"
    
    # Disable IPv6
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    
    # Update package list
    apt update && apt upgrade -y
    
    # Install required packages
    if ! apt install -y "${REQUIRED_PACKAGES[@]}"; then
        print_error "Failed to install required packages"
        return 1
    fi
    
    # Cleanup
    apt autoremove -y
    apt clean
    
    print_success "REQUIRED DEPENDENCIES INSTALLED SUCCESSFULLY"
    return 0
}

# Function to generate random string
generate_random_string() {
    local length="${1:-4}"
    local char_set="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local rand_string=$(LC_CTYPE=C tr -dc "$char_set" < /dev/urandom | head -c "$length")
    echo "$rand_string"
}

# Function to ask for domain
ask_domain() {
    while true; do
        read -rp "Do you have a Domain? (y/n): " ANS
        case "$ANS" in
            y|Y)
                check_domain
                break
                ;;
            *)
                print_info "It's okay, we'll set up a free domain for you."
                request_domain
                break
                ;;
        esac
    done
}

# Function to check domain
check_domain() {
    clear
    read -rp "${YELLOW}Enter Domain Name: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    local ip_domain=$(host -t A "$DOMAIN" | awk '{print $4}')
    if [[ "$ip_domain" != "$IP" ]]; then
        print_error "Domain name not verified or A record is not published."
        print_info "Expected IP: $IP, Got: $ip_domain"
        return 1
    else
        clear
        print_success "Domain added successfully"
        echo "$DOMAIN" > "$DOMAIN_FILE"
        export DOMAIN=$DOMAIN
        return 0
    fi
}

# Function to request domain from Cloudflare
request_domain() {
    clear
    print_info "Request new domain for ${IP}"
    
    # Check if Cloudflare credentials are set
    if [ -z "$CF_EMAIL" ] || [ -z "$CF_API" ] || [ -z "$CF_ZONE" ]; then
        print_error "Cloudflare credentials not configured"
        print_info "Please set CF_EMAIL, CF_API, and CF_ZONE environment variables"
        return 1
    fi
    
    local subdomain=$(generate_random_string)
    local retry=0
    local max_retry=3
    
    while [ $retry -lt $max_retry ]; do
        # Add the subdomain to Cloudflare
        local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records" \
        -H "X-Auth-Email: ${CF_EMAIL}" \
        -H "X-Auth-Key: ${CF_API}" \
        -H "Content-Type: application/json" \
        --data '{
        "type": "A",
        "name": "'"${subdomain}"'",
        "content": "'"${IP}"'",
        "ttl": 1,
        "proxied": false
        }')
        
        # Check response from Cloudflare
        local status=$(echo "$response" | jq -r '.success')
        if [[ "$status" == 'true' ]]; then
            DOMAIN="${subdomain}.yourdomain.com"  # Replace with actual domain
            print_success "Added domain for your vps success!"
            echo "$DOMAIN" > "$DOMAIN_FILE"
            export DOMAIN=$DOMAIN
            print_info "Domain anda: $DOMAIN"
            return 0
        else
            print_error "Add subdomain to Cloudflare failed. Retrying..."
            retry=$((retry + 1))
            sleep 2
        fi
    done
    
    print_error "Max retry reached, failed add subdomain to cloudflare."
    return 1
}

# Function to install all services
install_services() {
    local services=("certificate" "xray-core" "openvpn" "ssh-vpn")
    local failed_services=()
    
    for service in "${services[@]}"; do
        print_info "Installing $service..."
        
        if ! download_file "${GITHUB_RAW_REPO}/installer/$service" "/tmp/$service"; then
            print_error "Failed to download $service installer"
            failed_services+=("$service")
            continue
        fi
        
        chmod +x "/tmp/$service"
        
        if ! "/tmp/$service"; then
            print_error "Failed to install $service"
            failed_services+=("$service")
            rollback_installation "$service"
        fi
        
        rm -f "/tmp/$service"
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        print_error "Failed to install services: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# Function to run validation
run_validation() {
    print_info "Running installation validation..."
    
    if [ -f "bin/validate-installation.sh" ]; then
        if ! bash bin/validate-installation.sh; then
            print_warning "Some validation checks failed"
        fi
    else
        print_warning "Validation script not found"
    fi
}

# Main function
main() {
    print_info "Starting Autoscript Tunneling Installation..."
    
    # Pre-installation checks
    check_root
    check_virt
    check_internet
    check_os
    
    # Setup environment
    if ! first_setup; then
        print_error "Failed to setup environment"
        exit 1
    fi
    
    # Install dependencies
    if ! setup_dependencies; then
        print_error "Failed to install dependencies"
        exit 1
    fi
    
    # Setup domain
    if ! ask_domain; then
        print_error "Failed to setup domain"
        exit 1
    fi
    
    # Install services
    if ! install_services; then
        print_error "Failed to install some services"
        exit 1
    fi
    
    # Run validation
    run_validation
    
    echo
    print_success "=============================================="
    print_success "          QUICK INSTALL SELESAI!"
    print_success "=============================================="
    echo
    
    print_info "Installation completed. Please check the validation report above."
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi