#!/bin/bash

# Yuipedia Tunneling - Main Installer
# Production-ready tunneling solution for Debian 11+ and Ubuntu 22.04+
# 
# Author: Yuipedia
# Version: 2.0.0
# License: MIT
#
# Quick Install:
# wget -O install.sh https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh && chmod +x install.sh && ./install.sh

# Exit on any error
set -e

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' 

# Installation directories
readonly INSTALL_DIR="/opt/autoscript"
readonly CONFIG_DIR="/etc/autoscript"
readonly BIN_DIR="/usr/local/bin"
readonly LOG_DIR="/var/log/autoscript"

# GitHub repository configuration
readonly GITHUB_USER="xenvoid404"
readonly GITHUB_REPO="autoscript-tunneling"
readonly GITHUB_BRANCH="master"
readonly REPO_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Print functions
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║               Modern Tunneling Autoscript               ║"
    echo "║                    Version 2.0.0                        ║"
    echo "║                                                          ║"
    echo "║  Production-ready tunneling solution with:              ║"
    echo "║  • SSH & Dropbear SSH                                   ║"
    echo "║  • Xray-core (VMess, VLESS, Trojan)                    ║"
    echo "║  • WebSocket tunneling                                   ║"
    echo "║  • Advanced account management                           ║"
    echo "║  • System optimization                                   ║"
    echo "║                                                          ║"
    echo "║  Compatible: Debian 11+ | Ubuntu 22.04+                ║"
    echo "║  Installation: One-command via wget                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[STEP]${NC} ${WHITE}$1${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..60})${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# System compatibility check
check_system_compatibility() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
    fi
    
    # Get OS information
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "Cannot detect OS information"
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
        # For versions like 11.9, convert to 1190 (11 * 100 + 90)
        # For integer versions like 11, convert to 1100 (11 * 100 + 0)
        if [[ "$v1_minor" =~ ^[0-9]+$ ]] && [[ ${#v1_minor} -eq 1 ]]; then
            v1_minor=$((v1_minor * 10))  # 9 becomes 90
        fi
        if [[ "$v2_minor" =~ ^[0-9]+$ ]] && [[ ${#v2_minor} -eq 1 ]]; then
            v2_minor=$((v2_minor * 10))  # 9 becomes 90
        fi
        
        local v1_int=$((v1_major * 100 + v1_minor))
        local v2_int=$((v2_major * 100 + v2_minor))
        
        case $operator in
            ">=")
                [[ $v1_int -ge $v2_int ]]
                ;;
            ">")
                [[ $v1_int -gt $v2_int ]]
                ;;
            "=")
                [[ $v1_int -eq $v2_int ]]
                ;;
            "<")
                [[ $v1_int -lt $v2_int ]]
                ;;
            "<=")
                [[ $v1_int -le $v2_int ]]
                ;;
            *)
                return 1
                ;;
        esac
    }

    # Check OS compatibility
    case $OS in
        "Ubuntu")
            if ! version_compare "$VER" ">=" "22.04"; then
                print_error "Ubuntu 22.04+ required. Current: $VER"
                exit 1
            fi
            ;;
        "Debian GNU/Linux")
            if ! version_compare "$VER" ">=" "11"; then
                print_error "Debian 11+ required. Current: $VER"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Supported: Debian 11+ or Ubuntu 22.04+"
            exit 1
            ;;
    esac
    
    print_success "OS compatibility check passed: $OS $VER"
}

# Check internet connectivity
check_internet() {
    print_info "Checking internet connectivity..."
    
    # Test connectivity to multiple servers
    local test_hosts=("8.8.8.8" "1.1.1.1" "github.com")
    local connectivity=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &> /dev/null; then
            connectivity=true
            break
        fi
    done
    
    if [[ "$connectivity" == "true" ]]; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connectivity detected"
        print_info "Please check your network connection and try again"
        exit 1
    fi
}

# Install basic dependencies
install_basic_dependencies() {
    print_step "Installing Basic Dependencies"
    
    print_info "Updating package repository..."
    if apt-get update &> /dev/null; then
        print_success "Package repository updated"
    else
        print_error "Failed to update package repository"
        exit 1
    fi
    
    print_info "Installing essential packages..."
    local essential_packages=(
        "curl" "wget" "unzip" "tar" "gzip" "jq" "bc" 
        "uuid-runtime" "net-tools" "lsof" "cron" "logrotate"
        "openssl" "ca-certificates" "gnupg" "lsb-release"
    )
    
    for package in "${essential_packages[@]}"; do
        if apt-get install -y "$package" &> /dev/null; then
            print_success "Installed: $package"
        else
            print_error "Failed to install: $package"
            exit 1
        fi
    done
}

# Create directory structure
create_directory_structure() {
    print_step "Creating Directory Structure"
    
    local directories=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/scripts/system"
        "$INSTALL_DIR/scripts/services"
        "$INSTALL_DIR/scripts/accounts"
        "$INSTALL_DIR/utils"
        "$INSTALL_DIR/config"
        "$CONFIG_DIR"
        "$CONFIG_DIR/accounts"
        "$LOG_DIR"
        "/var/lib/autoscript"
        "/usr/local/bin/autoscript-mgmt"
        "/usr/local/bin/xray-mgmt"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            chmod 755 "$dir"
            print_success "Created: $dir"
        else
            print_error "Failed to create: $dir"
            exit 1
        fi
    done
}

# Download file with retry mechanism
download_file_with_retry() {
    local url="$1"
    local destination="$2"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        print_info "Downloading $(basename "$destination") (attempt $attempt/$max_attempts)..."
        
        if wget -q --show-progress --timeout=30 --tries=2 -O "$destination" "$url"; then
            print_success "Downloaded: $(basename "$destination")"
            return 0
        else
            print_warning "Download attempt $attempt failed"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 2
            fi
        fi
    done
    
    print_error "Failed to download after $max_attempts attempts: $url"
    return 1
}

# Download and install autoscript files from GitHub
download_autoscript_files() {
    print_step "Downloading Autoscript Files from GitHub"
    
    # Define files to download with their destinations
    declare -A files_to_download=(
        # Utility files
        ["utils/common.sh"]="$INSTALL_DIR/utils/common.sh"
        ["utils/logger.sh"]="$INSTALL_DIR/utils/logger.sh"
        ["utils/validator.sh"]="$INSTALL_DIR/utils/validator.sh"
        
        # Configuration files
        ["config/system.conf"]="$INSTALL_DIR/config/system.conf"
        ["config/xray.json"]="$INSTALL_DIR/config/xray.json"
        
        # System scripts
        ["scripts/system/deps.sh"]="$INSTALL_DIR/scripts/system/deps.sh"
        ["scripts/system/optimize.sh"]="$INSTALL_DIR/scripts/system/optimize.sh"
        ["scripts/system/firewall.sh"]="$INSTALL_DIR/scripts/system/firewall.sh"
        
        # Service scripts
        ["scripts/services/ssh.sh"]="$INSTALL_DIR/scripts/services/ssh.sh"
        ["scripts/services/xray.sh"]="$INSTALL_DIR/scripts/services/xray.sh"
        
        # Account management scripts
        ["scripts/accounts/ssh-account.sh"]="$INSTALL_DIR/scripts/accounts/ssh-account.sh"
    )
    
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
        print_error "Failed to download the following files:"
        for file in "${failed_downloads[@]}"; do
            print_error "  - $file"
        done
        print_info "Please check your internet connection and GitHub repository access"
        exit 1
    fi
    
    # Set proper permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/config/system.conf"
    
    print_success "All autoscript files downloaded successfully"
}

# Test GitHub connectivity
test_github_connectivity() {
    print_info "Testing GitHub connectivity..."
    
    local test_url="$REPO_URL/README.md"
    if wget -q --spider --timeout=10 "$test_url"; then
        print_success "GitHub repository accessible"
        return 0
    else
        print_error "Cannot access GitHub repository"
        print_info "Repository: $REPO_URL"
        print_info "Please check:"
        print_info "1. Internet connectivity"
        print_info "2. GitHub repository exists and is public"
        print_info "3. Repository URL is correct"
        return 1
    fi
}

# Run system optimization
run_system_optimization() {
    print_step "Running System Optimization"
    
    if [[ -f "$INSTALL_DIR/scripts/system/optimize.sh" ]]; then
        print_info "Running system optimization script..."
        if bash "$INSTALL_DIR/scripts/system/optimize.sh"; then
            print_success "System optimization completed"
        else
            print_warning "System optimization had some issues"
        fi
    else
        print_error "System optimization script not found"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    print_step "Installing Service Dependencies"
    
    if [[ -f "$INSTALL_DIR/scripts/system/deps.sh" ]]; then
        print_info "Running dependency installation script..."
        if bash "$INSTALL_DIR/scripts/system/deps.sh"; then
            print_success "Dependencies installed successfully"
        else
            print_error "Dependency installation failed"
            exit 1
        fi
    else
        print_error "Dependency installation script not found"
        exit 1
    fi
}

# Setup SSH services
setup_ssh_services() {
    print_step "Setting Up SSH Services"
    
    if [[ -f "$INSTALL_DIR/scripts/services/ssh.sh" ]]; then
        print_info "Configuring SSH and Dropbear services..."
        if bash "$INSTALL_DIR/scripts/services/ssh.sh"; then
            print_success "SSH services configured successfully"
        else
            print_error "SSH services configuration failed"
            exit 1
        fi
    else
        print_error "SSH setup script not found"
        exit 1
    fi
}

# Setup Xray services
setup_xray_services() {
    print_step "Setting Up Xray-core Services"
    
    if [[ -f "$INSTALL_DIR/scripts/services/xray.sh" ]]; then
        print_info "Configuring Xray-core with VMess, VLESS, and Trojan..."
        if bash "$INSTALL_DIR/scripts/services/xray.sh"; then
            print_success "Xray-core configured successfully"
        else
            print_error "Xray-core configuration failed"
            exit 1
        fi
    else
        print_error "Xray setup script not found"
        exit 1
    fi
}

# Setup firewall
setup_firewall() {
    print_step "Configuring Firewall"
    
    if [[ -f "$INSTALL_DIR/scripts/system/firewall.sh" ]]; then
        print_info "Running firewall configuration script..."
        if bash "$INSTALL_DIR/scripts/system/firewall.sh"; then
            print_success "Firewall configured successfully"
        else
            print_warning "Firewall configuration had issues"
        fi
    else
        print_info "Installing and configuring UFW firewall manually..."
        
        # Install UFW if not present
        if ! command -v ufw &> /dev/null; then
            apt-get install -y ufw &> /dev/null
        fi
        
        # Reset UFW to defaults
        ufw --force reset &> /dev/null
        
        # Set default policies
        ufw default deny incoming &> /dev/null
        ufw default allow outgoing &> /dev/null
        
        # Allow SSH ports
        ufw allow 22/tcp comment "SSH" &> /dev/null
        ufw allow 109/tcp comment "Dropbear SSH" &> /dev/null
        ufw allow 143/tcp comment "Dropbear WebSocket" &> /dev/null
        
        # Allow Xray ports
        ufw allow 80/tcp comment "Xray VMess/VLESS" &> /dev/null
        ufw allow 443/tcp comment "Xray TLS" &> /dev/null
        
        # Allow WebSocket port
        ufw allow 8880/tcp comment "SSH WebSocket" &> /dev/null
        
        # Enable UFW
        ufw --force enable &> /dev/null
        
        print_success "Firewall configured and enabled"
    fi
}

# Create management commands
create_management_commands() {
    print_step "Creating Management Commands"
    
    # Create main menu script
    cat > "$BIN_DIR/autoscript" << 'EOF'
#!/bin/bash

# Modern Tunneling Autoscript - Main Menu
# Quick access to all autoscript functions

INSTALL_DIR="/opt/autoscript"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║               Modern Tunneling Autoscript               ║"
    echo "║                   Management Panel                      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_menu() {
    echo -e "${WHITE}Main Menu:${NC}"
    echo ""
    echo "  ${GREEN}1.${NC} SSH Account Management"
    echo "  ${GREEN}2.${NC} Xray Account Management" 
    echo "  ${GREEN}3.${NC} Service Management"
    echo "  ${GREEN}4.${NC} System Information"
    echo "  ${GREEN}5.${NC} View Logs"
    echo "  ${GREEN}6.${NC} Update System"
    echo "  ${GREEN}7.${NC} Backup & Restore"
    echo "  ${GREEN}0.${NC} Exit"
    echo ""
}

ssh_menu() {
    while true; do
        clear
        show_banner
        echo -e "${WHITE}SSH Account Management:${NC}"
        echo ""
        echo "  ${GREEN}1.${NC} Add SSH Account"
        echo "  ${GREEN}2.${NC} Delete SSH Account"
        echo "  ${GREEN}3.${NC} List SSH Accounts"
        echo "  ${GREEN}4.${NC} Show Account Details"
        echo "  ${GREEN}5.${NC} Extend Account"
        echo "  ${GREEN}6.${NC} Change Password"
        echo "  ${GREEN}7.${NC} Cleanup Expired"
        echo "  ${GREEN}0.${NC} Back to Main Menu"
        echo ""
        read -p "Select option [0-7]: " choice
        
        case $choice in
            1)
                read -p "Enter username: " username
                read -p "Enter validity days (default 30): " days
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" add "$username" "" "${days:-30}"
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Enter username to delete: " username
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" delete "$username"
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" list
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Enter username: " username
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" show "$username"
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Enter username: " username
                read -p "Enter additional days: " days
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" extend "$username" "$days"
                read -p "Press Enter to continue..."
                ;;
            6)
                read -p "Enter username: " username
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" password "$username"
                read -p "Press Enter to continue..."
                ;;
            7)
                bash "$INSTALL_DIR/scripts/accounts/ssh-account.sh" cleanup
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

xray_menu() {
    while true; do
        clear
        show_banner
        echo -e "${WHITE}Xray Account Management:${NC}"
        echo ""
        echo "  ${GREEN}1.${NC} Add VMess Account"
        echo "  ${GREEN}2.${NC} Add VLESS Account"
        echo "  ${GREEN}3.${NC} Add Trojan Account"
        echo "  ${GREEN}4.${NC} List All Clients"
        echo "  ${GREEN}5.${NC} Remove Client"
        echo "  ${GREEN}6.${NC} Generate Config"
        echo "  ${GREEN}0.${NC} Back to Main Menu"
        echo ""
        read -p "Select option [0-6]: " choice
        
        case $choice in
            1)
                read -p "Enter username: " username
                /usr/local/bin/xray-client add vmess "$username" 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Enter username: " username
                /usr/local/bin/xray-client add vless "$username" 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            3)
                read -p "Enter username: " username
                /usr/local/bin/xray-client add trojan "$username" 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            4)
                /usr/local/bin/xray-client list 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Enter username to remove: " username
                /usr/local/bin/xray-client remove "$username" 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            6)
                read -p "Enter username: " username
                server_ip=$(curl -s4 ifconfig.me 2>/dev/null || echo "Unable to get IP")
                /usr/local/bin/xray-client config "$username" "$server_ip" 2>/dev/null || echo "Xray client manager not found"
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

show_system_info() {
    clear
    show_banner
    echo -e "${WHITE}System Information:${NC}"
    echo ""
    
    # System details
    echo -e "${CYAN}System:${NC}"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    # Resource usage
    echo -e "${CYAN}Resources:${NC}"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"
    echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
    echo ""
    
    # Network
    echo -e "${CYAN}Network:${NC}"
    echo "Public IP: $(curl -s4 ifconfig.me 2>/dev/null || echo 'Unable to get IP')"
    echo ""
    
    # Services
    echo -e "${CYAN}Service Status:${NC}"
    for service in ssh dropbear xray; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo -e "$service: ${GREEN}Running${NC}"
        else
            echo -e "$service: ${RED}Stopped${NC}"
        fi
    done
    
    read -p "Press Enter to continue..."
}

main_loop() {
    while true; do
        show_banner
        show_menu
        read -p "Select option [0-7]: " choice
        
        case $choice in
            1) ssh_menu ;;
            2) xray_menu ;;
            3) 
                echo "Service management features:"
                echo "- Restart SSH: systemctl restart ssh"
                echo "- Restart Dropbear: systemctl restart dropbear"
                echo "- Restart Xray: systemctl restart xray"
                echo "- Check Status: systemctl status [service]"
                read -p "Press Enter to continue..."
                ;;
            4) show_system_info ;;
            5)
                echo "Log locations:"
                echo "- Main log: /var/log/autoscript/autoscript.log"
                echo "- Error log: /var/log/autoscript/error.log"
                echo "- Access log: /var/log/autoscript/access.log"
                echo "- Xray logs: /var/log/xray/"
                echo ""
                echo "View logs with: tail -f /var/log/autoscript/autoscript.log"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "Updating system packages..."
                apt update && apt upgrade -y
                echo "System updated!"
                read -p "Press Enter to continue..."
                ;;
            7)
                echo "Backup & restore features:"
                echo "- Configuration backup: tar -czf autoscript-backup.tar.gz /opt/autoscript /etc/autoscript"
                echo "- Account backup: cp /etc/autoscript/accounts/* /backup/"
                echo "- Restore: Extract backup and restart services"
                read -p "Press Enter to continue..."
                ;;
            0)
                echo -e "${GREEN}Thank you for using Modern Tunneling Autoscript!${NC}"
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

main_loop
EOF
    
    chmod +x "$BIN_DIR/autoscript"
    
    # Create symbolic links for account management
    if [[ -f "$INSTALL_DIR/scripts/accounts/ssh-account.sh" ]]; then
        ln -sf "$INSTALL_DIR/scripts/accounts/ssh-account.sh" "$BIN_DIR/ssh-account"
    fi
    
    print_success "Management commands created"
    print_info "Main menu: autoscript"
    print_info "SSH accounts: ssh-account"
    print_info "Xray clients: xray-client (if Xray is installed)"
}

# Setup cron jobs for maintenance
setup_cron_jobs() {
    print_step "Setting Up Maintenance Tasks"
    
    # Create cron job for account cleanup
    cat > /tmp/autoscript_cron << EOF
# Modern Tunneling Autoscript - Maintenance Jobs
# Clean expired accounts every hour
0 * * * * /opt/autoscript/scripts/accounts/ssh-account.sh cleanup >/dev/null 2>&1

# Clean logs every 6 hours
0 */6 * * * find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;

# Restart services daily at 3 AM
0 3 * * * systemctl restart ssh dropbear xray >/dev/null 2>&1
EOF
    
    # Install cron jobs
    crontab /tmp/autoscript_cron
    rm /tmp/autoscript_cron
    
    print_success "Maintenance tasks scheduled"
}

# Final verification
verify_installation() {
    print_step "Verifying Installation"
    
    local verification_failed=false
    
    # Check essential files
    local essential_files=(
        "$INSTALL_DIR/utils/common.sh"
        "$INSTALL_DIR/config/system.conf"
        "$BIN_DIR/autoscript"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "✓ $file"
        else
            print_error "✗ $file"
            verification_failed=true
        fi
    done
    
    # Check services
    local services=("ssh" "cron")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "✓ $service service"
        else
            print_error "✗ $service service"
            verification_failed=true
        fi
    done
    
    # Check commands
    local commands=("autoscript")
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "✓ $cmd command"
        else
            print_error "✗ $cmd command"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        print_error "Installation verification failed"
        exit 1
    else
        print_success "Installation verification passed"
    fi
}

# Show installation summary
show_installation_summary() {
    clear
    print_banner
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              INSTALLATION COMPLETED SUCCESSFULLY         ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}Installed Services:${NC}"
    echo "✓ SSH Server (Port 22)"
    echo "✓ Dropbear SSH (Port 109)"
    echo "✓ Dropbear WebSocket (Port 143)"
    echo "✓ Xray-core with VMess/VLESS/Trojan"
    echo "✓ WebSocket Tunneling (Port 8880)"
    echo "✓ System Optimization Applied"
    echo "✓ Firewall Configured"
    echo "✓ Account Management System"
    
    echo -e "\n${CYAN}Management Commands:${NC}"
    echo "• Main menu: ${WHITE}autoscript${NC}"
    echo "• SSH accounts: ${WHITE}ssh-account${NC}"
    echo "• Xray clients: ${WHITE}xray-client${NC} (if available)"
    
    echo -e "\n${CYAN}Quick Start:${NC}"
    echo "1. Run ${WHITE}autoscript${NC} to access the main menu"
    echo "2. Create SSH account: ${WHITE}ssh-account add username${NC}"
    echo "3. Create Xray client: ${WHITE}xray-client add vmess username${NC}"
    
    local server_ip=$(curl -s4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo -e "\n${CYAN}Server Information:${NC}"
    echo "Server IP: ${WHITE}$server_ip${NC}"
    echo "SSH Port: ${WHITE}22${NC}"
    echo "Dropbear Port: ${WHITE}109${NC}"
    echo "Dropbear WS Port: ${WHITE}143${NC}"
    echo "WebSocket Port: ${WHITE}8880${NC}"
    
    echo -e "\n${CYAN}Installation Method:${NC}"
    echo "✓ Downloaded from GitHub via wget"
    echo "✓ One-command installation"
    echo "✓ Remote installation capability"
    
    echo -e "\n${CYAN}Important Notes:${NC}"
    echo "• All services are secured with fail2ban"
    echo "• System optimizations are applied"
    echo "• Automatic maintenance tasks are scheduled"
    echo "• Logs are located in /var/log/autoscript/"
    
    echo -e "\n${GREEN}Installation completed successfully!${NC}"
    echo -e "Repository: ${REPO_URL}"
    echo ""
}

# Main installation function
main() {
    # Check if already installed
    if [[ -f "$INSTALL_DIR/utils/common.sh" ]]; then
        print_warning "Autoscript appears to be already installed"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    fi
    
    print_banner
    
    print_info "Starting Modern Tunneling Autoscript installation..."
    print_info "Repository: $REPO_URL"
    print_info "This will install and configure tunneling services on your server"
    echo ""
    
    # Auto-confirm if script is running via pipe (non-interactive)
    if [[ -t 0 ]]; then
        # Interactive mode - ask for confirmation
        read -p "Do you want to continue with the installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    else
        # Non-interactive mode (via pipe) - auto-confirm
        print_info "Running in non-interactive mode, auto-confirming installation..."
        echo "Continuing with installation..."
    fi
    
    echo ""
    print_info "Installation started..."
    
    # Run installation steps
    check_system_compatibility
    check_internet
    
    # Test GitHub connectivity before proceeding
    if ! test_github_connectivity; then
        print_error "Cannot proceed without GitHub access"
        exit 1
    fi
    
    install_basic_dependencies
    create_directory_structure
    download_autoscript_files
    install_dependencies
    run_system_optimization
    setup_ssh_services
    setup_xray_services
    setup_firewall
    create_management_commands
    setup_cron_jobs
    verify_installation
    
    # Show summary
    show_installation_summary
    
    # Start main menu
    if [[ -t 0 ]]; then
        # Interactive mode
        read -p "Press Enter to open the management panel..."
        exec autoscript
    else
        # Non-interactive mode
        print_info "Installation completed in non-interactive mode"
        print_info "You can run 'autoscript' command to access the management panel"
    fi
}

# Run main function
main "$@"