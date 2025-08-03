#!/bin/bash

# Common utility functions for autoscript tunneling
# Compatible with Debian 11+ and Ubuntu 22.04+

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# System information
get_system_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        echo -e "${RED}Error: Cannot detect OS information${NC}"
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
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
check_compatibility() {
    get_system_info
    
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
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ OS compatibility check passed: $OS $VER${NC}"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                Modern Tunneling Autoscript              ║"
    echo "║                   Production Ready                      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print section header
print_section() {
    local title="$1"
    echo -e "\n${BLUE}[INFO]${NC} ${WHITE}$title${NC}"
    echo -e "${BLUE}$(printf '%.0s=' {1..60})${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print error message
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print info message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Generate random string
generate_random_string() {
    local length=${1:-12}
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# Generate UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        # Fallback UUID generation
        cat /proc/sys/kernel/random/uuid
    fi
}

# Check if port is available
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if systemctl is-active --quiet "$service_name"; then
            print_success "Service $service_name is ready"
            return 0
        fi
        
        print_info "Waiting for $service_name to start... ($((attempt + 1))/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    print_error "Service $service_name failed to start within timeout"
    return 1
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        chmod "$permissions" "$dir_path"
        print_info "Created directory: $dir_path"
    fi
}

# Backup file
backup_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up: $file_path"
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local destination="$2"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if wget -q --show-progress -O "$destination" "$url"; then
            print_success "Downloaded: $url"
            return 0
        fi
        
        print_warning "Download attempt $((attempt + 1)) failed for: $url"
        ((attempt++))
        sleep 2
    done
    
    print_error "Failed to download after $max_attempts attempts: $url"
    return 1
}

# Check internet connectivity
check_internet() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        return 0
    else
        print_error "No internet connectivity detected"
        return 1
    fi
}

# Get public IP
get_public_ip() {
    local ip
    ip=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || curl -s4 ipinfo.io/ip 2>/dev/null)
    
    if [[ -n "$ip" ]]; then
        echo "$ip"
    else
        print_error "Failed to get public IP"
        return 1
    fi
}

# Validate IP address
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        for octet in $(echo "$ip" | tr '.' ' '); do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Install package if not exists
install_package() {
    local package="$1"
    
    if ! dpkg -l | grep -q "^ii  $package "; then
        print_info "Installing package: $package"
        if apt-get update &> /dev/null && apt-get install -y "$package" &> /dev/null; then
            print_success "Installed: $package"
        else
            print_error "Failed to install: $package"
            return 1
        fi
    else
        print_info "Package already installed: $package"
    fi
}

# Enable and start service
enable_service() {
    local service_name="$1"
    
    systemctl enable "$service_name" &> /dev/null
    systemctl start "$service_name" &> /dev/null
    
    if systemctl is-active --quiet "$service_name"; then
        print_success "Service enabled and started: $service_name"
        return 0
    else
        print_error "Failed to start service: $service_name"
        return 1
    fi
}

# Disable and stop service
disable_service() {
    local service_name="$1"
    
    systemctl stop "$service_name" &> /dev/null
    systemctl disable "$service_name" &> /dev/null
    
    print_info "Service stopped and disabled: $service_name"
}

# Function to display loading animation
show_loading() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while [[ "$(ps a | awk '{print $1}' | grep $pid)" ]]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Execute command with loading animation
execute_with_loading() {
    local command="$1"
    local message="$2"
    
    print_info "$message"
    
    # Execute command in background
    eval "$command" &
    local pid=$!
    
    # Show loading animation
    show_loading $pid
    
    # Wait for command to complete
    wait $pid
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Completed: $message"
    else
        print_error "Failed: $message"
    fi
    
    return $exit_code
}

# Export functions for use in other scripts
export -f get_system_info check_root check_compatibility
export -f print_banner print_section print_success print_error print_warning print_info
export -f generate_random_string generate_uuid check_port wait_for_service
export -f create_directory backup_file download_file check_internet get_public_ip validate_ip
export -f command_exists install_package enable_service disable_service
export -f show_loading execute_with_loading