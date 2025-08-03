#!/bin/bash

# Common utility functions for autoscript tunneling
# Compatible with Debian 11+ and Ubuntu 22.04+

# System information
get_system_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        echo "Error: Cannot detect OS information"
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
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

# Get public IP address
get_public_ip() {
    local ip=""
    
    # Try multiple IP detection services
    local services=(
        "https://ipv4.icanhazip.com"
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://ipinfo.io/ip"
    )
    
    for service in "${services[@]}"; do
        if ip=$(curl -s --connect-timeout 10 --max-time 15 "$service" 2>/dev/null); then
            # Validate IP format
            if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "$ip"
                return 0
            fi
        fi
    done
    
    # Fallback to local IP detection
    ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi
    
    return 1
}

# Create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if mkdir -p "$dir_path" 2>/dev/null; then
        chmod "$permissions" "$dir_path"
        return 0
    else
        echo "Error: Failed to create directory: $dir_path"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is available
is_port_available() {
    local port="$1"
    ! ss -tuln | grep -q ":$port "
}

# Generate random string
generate_random_string() {
    local length="${1:-32}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Generate UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen
    else
        # Fallback UUID generation
        local uuid=""
        for i in {1..32}; do
            case $i in
                9|14|19|24) uuid+="-" ;;
            esac
            uuid+=$(printf "%x" $((RANDOM % 16)))
        done
        echo "$uuid"
    fi
}

# Validate IP address
validate_ip() {
    local ip="$1"
    [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Validate port number
validate_port() {
    local port="$1"
    [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]
}

# Download file with retry
download_file() {
    local url="$1"
    local destination="$2"
    local max_attempts="${3:-3}"
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

# Service management functions
start_service() {
    local service_name="$1"
    if systemctl start "$service_name" 2>/dev/null; then
        echo "Started service: $service_name"
        return 0
    else
        echo "Error: Failed to start service: $service_name"
        return 1
    fi
}

stop_service() {
    local service_name="$1"
    if systemctl stop "$service_name" 2>/dev/null; then
        echo "Stopped service: $service_name"
        return 0
    else
        echo "Error: Failed to stop service: $service_name"
        return 1
    fi
}

enable_service() {
    local service_name="$1"
    if systemctl enable "$service_name" 2>/dev/null; then
        echo "Enabled service: $service_name"
        return 0
    else
        echo "Error: Failed to enable service: $service_name"
        return 1
    fi
}

restart_service() {
    local service_name="$1"
    if systemctl restart "$service_name" 2>/dev/null; then
        echo "Restarted service: $service_name"
        return 0
    else
        echo "Error: Failed to restart service: $service_name"
        return 1
    fi
}

# Check service status
check_service_status() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name"
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_wait="${2:-30}"
    local count=0
    
    echo "Waiting for service $service_name to be ready..."
    while [[ $count -lt $max_wait ]]; do
        if check_service_status "$service_name"; then
            echo "Service $service_name is ready"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    echo "Error: Service $service_name failed to start within ${max_wait}s"
    return 1
}