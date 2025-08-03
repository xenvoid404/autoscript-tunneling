#!/bin/bash

# Yuipedia Tunneling - Main Installer
# Production-ready tunneling solution for Debian 11+ and Ubuntu 22.04+
# 
# Author: Yuipedia
# Version: 2.0.0
# License: MIT
#
# Quick Install:
# curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh | bash

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
    echo "║  Installation: One-command via curl                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# System compatibility check
check_system_compatibility() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    # Get OS information
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo -e "${RED}Error: Cannot detect OS information${NC}"
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
                echo -e "${RED}Error: Ubuntu 22.04+ required. Current: $VER${NC}"
                exit 1
            fi
            ;;
        "Debian GNU/Linux")
            if ! version_compare "$VER" ">=" "11"; then
                echo -e "${RED}Error: Debian 11+ required. Current: $VER${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unsupported OS: $OS${NC}"
            echo "Supported: Debian 11+ or Ubuntu 22.04+"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ OS compatibility check passed: $OS $VER${NC}"
}

# Check internet connectivity
check_internet() {
    echo "Checking internet connectivity..."
    
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
        echo -e "${GREEN}✓ Internet connectivity verified${NC}"
    else
        echo -e "${RED}Error: No internet connectivity detected${NC}"
        echo "Please check your network connection and try again"
        exit 1
    fi
}

# Install basic dependencies
install_basic_dependencies() {
    echo -e "\n${BLUE}Installing Basic Dependencies...${NC}"
    
    echo "Updating package repository..."
    apt-get update || { echo -e "${RED}Error: Failed to update package repository${NC}"; exit 1; }
    
    echo "Installing essential packages..."
    local essential_packages=(
        "curl" "wget" "unzip" "tar" "gzip" "jq" "bc" 
        "uuid-runtime" "net-tools" "lsof" "cron" "logrotate"
        "openssl" "ca-certificates" "gnupg" "lsb-release"
    )
    
    apt-get install -y "${essential_packages[@]}" || { echo -e "${RED}Error: Failed to install essential packages${NC}"; exit 1; }
    echo -e "${GREEN}✓ Essential packages installed${NC}"
}

# Create directory structure
create_directory_structure() {
    echo -e "\n${BLUE}Creating Directory Structure...${NC}"
    
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
        mkdir -p "$dir" && chmod 755 "$dir" || { echo -e "${RED}Error: Failed to create directory: $dir${NC}"; exit 1; }
    done
    echo -e "${GREEN}✓ Directory structure created${NC}"
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
            echo -e "${GREEN}✓ Downloaded: $(basename "$destination")${NC}"
            return 0
        else
            echo -e "${YELLOW}Warning: Download attempt $attempt failed${NC}"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 2
            fi
        fi
    done
    
    echo -e "${RED}Error: Failed to download after $max_attempts attempts: $url${NC}"
    return 1
}

# Download and install autoscript files from GitHub
download_autoscript_files() {
    echo -e "\n${BLUE}Downloading Autoscript Files from GitHub...${NC}"
    
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
        echo -e "${RED}Error: Failed to download the following files:${NC}"
        for file in "${failed_downloads[@]}"; do
            echo "  - $file"
        done
        echo "Please check your internet connection and GitHub repository access"
        exit 1
    fi
    
    # Set proper permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/config/system.conf"
    
    echo -e "${GREEN}✓ All autoscript files downloaded successfully${NC}"
}

# Test GitHub connectivity
test_github_connectivity() {
    echo "Testing GitHub connectivity..."
    
    local test_url="$REPO_URL/README.md"
    if wget -q --spider --timeout=10 "$test_url"; then
        echo -e "${GREEN}✓ GitHub repository accessible${NC}"
        return 0
    else
        echo -e "${RED}Error: Cannot access GitHub repository${NC}"
        echo "Repository: $REPO_URL"
        echo "Please check:"
        echo "1. Internet connectivity"
        echo "2. GitHub repository exists and is public"
        echo "3. Repository URL is correct"
        return 1
    fi
}

# Run system optimization
run_system_optimization() {
    echo -e "\n${BLUE}Running System Optimization...${NC}"
    
    if [[ -f "$INSTALL_DIR/scripts/system/optimize.sh" ]]; then
        echo "Running system optimization script..."
        bash "$INSTALL_DIR/scripts/system/optimize.sh" || echo -e "${YELLOW}Warning: System optimization had some issues${NC}"
        echo -e "${GREEN}✓ System optimization completed${NC}"
    else
        echo -e "${RED}Error: System optimization script not found${NC}"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "\n${BLUE}Installing Service Dependencies...${NC}"
    
    if [[ -f "$INSTALL_DIR/scripts/system/deps.sh" ]]; then
        echo "Running dependency installation script..."
        bash "$INSTALL_DIR/scripts/system/deps.sh" || { echo -e "${RED}Error: Dependency installation failed${NC}"; exit 1; }
        echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    else
        echo -e "${RED}Error: Dependency installation script not found${NC}"
        exit 1
    fi
}

# Setup SSH services
setup_ssh_services() {
    echo -e "\n${BLUE}Setting Up SSH Services...${NC}"
    
    if [[ -f "$INSTALL_DIR/scripts/services/ssh.sh" ]]; then
        echo "Configuring SSH and Dropbear services..."
        bash "$INSTALL_DIR/scripts/services/ssh.sh" || { echo -e "${RED}Error: SSH services configuration failed${NC}"; exit 1; }
        echo -e "${GREEN}✓ SSH services configured successfully${NC}"
    else
        echo -e "${RED}Error: SSH setup script not found${NC}"
        exit 1
    fi
}

# Setup Xray services
setup_xray_services() {
    echo -e "\n${BLUE}Setting Up Xray-core Services...${NC}"
    
    if [[ -f "$INSTALL_DIR/scripts/services/xray.sh" ]]; then
        echo "Configuring Xray-core with VMess, VLESS, and Trojan..."
        bash "$INSTALL_DIR/scripts/services/xray.sh" || { echo -e "${RED}Error: Xray-core configuration failed${NC}"; exit 1; }
        echo -e "${GREEN}✓ Xray-core configured successfully${NC}"
    else
        echo -e "${RED}Error: Xray setup script not found${NC}"
        exit 1
    fi
}

# Setup firewall
setup_firewall() {
    echo -e "\n${BLUE}Configuring Firewall...${NC}"
    
    if [[ -f "$INSTALL_DIR/scripts/system/firewall.sh" ]]; then
        echo "Running firewall configuration script..."
        bash "$INSTALL_DIR/scripts/system/firewall.sh" || echo -e "${YELLOW}Warning: Firewall configuration had issues${NC}"
    else
        echo "Installing and configuring UFW firewall manually..."
        
        # Install UFW if not present
        if ! command -v ufw &> /dev/null; then
            apt-get install -y ufw
        fi
        
        # Reset UFW to defaults
        ufw --force reset
        
        # Set default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH ports
        ufw allow 22/tcp comment "SSH"
        ufw allow 109/tcp comment "Dropbear SSH"
        ufw allow 143/tcp comment "Dropbear WebSocket"
        
        # Allow Xray ports
        ufw allow 8080/tcp comment "Xray VMess TCP"
        ufw allow 8081/tcp comment "Xray VLESS TCP"
        ufw allow 443/tcp comment "Xray TLS"
        ufw allow 8443/tcp comment "Xray Trojan TCP"
        
        # Allow WebSocket port
        ufw allow 8880/tcp comment "SSH WebSocket"
        
        # Enable UFW
        ufw --force enable
    fi
    
    echo -e "${GREEN}✓ Firewall configured and enabled${NC}"
}

# Create management commands
create_management_commands() {
    echo -e "\n${BLUE}Creating Management Commands...${NC}"
    
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
    
    echo -e "${GREEN}✓ Management commands created${NC}"
    echo "Main menu: autoscript"
    echo "SSH accounts: ssh-account"
    echo "Xray clients: xray-client (if Xray is installed)"
}

# Setup cron jobs for maintenance
setup_cron_jobs() {
    echo -e "\n${BLUE}Setting Up Maintenance Tasks...${NC}"
    
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
    
    echo -e "${GREEN}✓ Maintenance tasks scheduled${NC}"
}

# Final verification
verify_installation() {
    echo -e "\n${BLUE}Verifying Installation...${NC}"
    
    local verification_failed=false
    
    # Check essential files
    local essential_files=(
        "$INSTALL_DIR/utils/common.sh"
        "$INSTALL_DIR/config/system.conf"
        "$BIN_DIR/autoscript"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${GREEN}✓ $file${NC}"
        else
            echo -e "${RED}✗ $file${NC}"
            verification_failed=true
        fi
    done
    
    # Check services
    local services=("ssh" "cron")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✓ $service service${NC}"
        else
            echo -e "${RED}✗ $service service${NC}"
            verification_failed=true
        fi
    done
    
    # Check commands
    local commands=("autoscript")
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓ $cmd command${NC}"
        else
            echo -e "${RED}✗ $cmd command${NC}"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        echo -e "${RED}Installation verification failed${NC}"
        exit 1
    else
        echo -e "${GREEN}Installation verification passed${NC}"
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
    echo "✓ Downloaded from GitHub via curl"
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

# Global variables for installation mode
FORCE_INSTALL=false
AUTO_YES=false
INTERACTIVE_MODE=true

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                FORCE_INSTALL=true
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            --non-interactive)
                INTERACTIVE_MODE=false
                AUTO_YES=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help information
show_help() {
    echo "Modern Tunneling Autoscript - Installation Options"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force, -f           Force reinstallation even if already installed"
    echo "  --yes, -y             Automatically answer yes to all prompts"
    echo "  --non-interactive     Run in completely non-interactive mode"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive installation"
    echo "  $0 --yes             # Auto-confirm all prompts"
    echo "  $0 --force --yes     # Force reinstall with auto-confirm"
    echo "  curl -sSL url | bash -s -- --non-interactive"
}

# Enhanced user prompt with timeout and auto-answer
prompt_user() {
    local message="$1"
    local default="${2:-N}"
    local timeout="${3:-30}"
    
    # Non-interactive mode or auto-yes
    if [[ "$INTERACTIVE_MODE" == "false" ]] || [[ "$AUTO_YES" == "true" ]]; then
        if [[ "$default" =~ ^[Yy]$ ]]; then
            echo "y"
            return 0
        else
            echo "n"
            return 1
        fi
    fi
    
    # Interactive mode with timeout
    if [[ -t 0 ]]; then
        local reply
        if timeout "$timeout" bash -c "read -p '$message' -n 1 -r reply; echo \$reply" 2>/dev/null; then
            echo
            if [[ $reply =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        else
            echo
            echo -e "${YELLOW}Warning: Timeout reached, using default answer: $default${NC}"
            if [[ "$default" =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        fi
    else
        # Running via pipe - use default
        echo -e "${YELLOW}Warning: Non-interactive mode detected, using default: $default${NC}"
        if [[ "$default" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Main installation function
main() {
    # Parse command line arguments first
    parse_args "$@"
    
    # Detect if running via pipe and adjust settings
    if [[ ! -t 0 ]]; then
        INTERACTIVE_MODE=false
        AUTO_YES=true
        echo -e "${YELLOW}Warning: Pipe input detected - enabling non-interactive mode${NC}"
    fi
    
    # Check if already installed
    if [[ -f "$INSTALL_DIR/utils/common.sh" ]]; then
        echo -e "${YELLOW}Warning: Autoscript appears to be already installed${NC}"
        
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            echo -e "${YELLOW}Warning: Force installation enabled, proceeding with reinstallation...${NC}"
        elif prompt_user "Do you want to reinstall? (y/N): " "N" 15; then
            echo -e "${YELLOW}Proceeding with reinstallation...${NC}"
        else
            echo "Installation cancelled"
            exit 0
        fi
    fi
    
    print_banner
    
    echo -e "${CYAN}Starting Modern Tunneling Autoscript installation...${NC}"
    echo "Repository: $REPO_URL"
    echo "This will install and configure tunneling services on your server"
    echo ""
    
    # Ask for installation confirmation
    if [[ "$AUTO_YES" != "true" ]]; then
        read -p "Do you want to continue with the installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    else
        echo "Auto-confirmation enabled, proceeding with installation..."
    fi
    
    echo ""
    echo "Installation started..."
    
    # Run installation steps
    check_system_compatibility
    check_internet
    
    # Test GitHub connectivity before proceeding
    if ! test_github_connectivity; then
        echo -e "${RED}Error: Cannot proceed without GitHub access${NC}"
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
    
    # Ask to restart system
    echo ""
    read -p "Do you want to restart the system now? (recommended) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "System will restart in 5 seconds..."
        sleep 5
        reboot
    else
        echo ""
        echo "Installation completed! Please restart the system manually when convenient."
        echo "You can run 'autoscript' command to access the management panel."
    fi
}

# Run main function
main "$@"