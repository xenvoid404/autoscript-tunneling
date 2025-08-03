#!/bin/bash

# Modern Tunneling Autoscript - Quick Install Script
# One-command installation via wget
#
# Usage:
# wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | bash
# 
# or
#
# curl -fsSL https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# GitHub configuration
GITHUB_USER="xenvoid404"  # Ganti dengan username GitHub Anda
GITHUB_REPO="autoscript-tunneling"
GITHUB_BRANCH="master"
INSTALLER_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh"

# Print functions
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║             Modern Tunneling Autoscript                 ║"
    echo "║               Quick Install Script                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo bash or su -"
        exit 1
    fi
}

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

# Check system compatibility
check_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case $NAME in
            "Ubuntu")
                if ! version_compare "$VERSION_ID" ">=" "22.04"; then
                    print_error "Ubuntu 22.04+ required. Current: $VERSION_ID"
                    exit 1
                fi
                ;;
            "Debian GNU/Linux")
                if ! version_compare "$VERSION_ID" ">=" "11"; then
                    print_error "Debian 11+ required. Current: $VERSION_ID"
                    exit 1
                fi
                ;;
            *)
                print_error "Unsupported OS: $NAME"
                exit 1
                ;;
        esac
        print_success "OS Check: $NAME $VERSION_ID"
    else
        print_error "Cannot detect OS information"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    if ping -c 1 -W 3 github.com &> /dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connectivity to GitHub"
        exit 1
    fi
}

# Download and run main installer
download_and_run() {
    print_info "Downloading main installer from GitHub..."
    
    local temp_installer="/tmp/autoscript-installer.sh"
    
    if wget -q --show-progress --timeout=30 -O "$temp_installer" "$INSTALLER_URL"; then
        print_success "Installer downloaded successfully"
        
        # Make executable
        chmod +x "$temp_installer"
        
        print_info "Starting main installation..."
        echo ""
        
        # Run the main installer
        exec bash "$temp_installer"
    else
        print_error "Failed to download installer"
        print_info "URL: $INSTALLER_URL"
        print_info "Please check:"
        print_info "1. Internet connection"
        print_info "2. GitHub repository access"
        print_info "3. Repository URL is correct"
        exit 1
    fi
}

# Main function
main() {
    print_banner
    
    echo -e "${CYAN}Repository:${NC} https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
    echo -e "${CYAN}Installer URL:${NC} $INSTALLER_URL"
    echo ""
    
    print_info "Quick installation started..."
    
    # Pre-flight checks
    check_root
    check_system
    check_internet
    
    # Install basic requirements for wget if needed
    if ! command -v wget &> /dev/null; then
        print_info "Installing wget..."
        apt-get update &> /dev/null
        apt-get install -y wget &> /dev/null
    fi
    
    # Download and run main installer
    download_and_run
}

# Run main function
main "$@"