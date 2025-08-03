#!/bin/bash

# Input validation utility for autoscript tunneling
# Provides comprehensive validation functions

# Source common utilities if available
[[ -f "$(dirname "$0")/common.sh" ]] && source "$(dirname "$0")/common.sh"

# Validate username
validate_username() {
    local username="$1"
    local min_length="${2:-3}"
    local max_length="${3:-32}"
    
    # Check if username is provided
    if [[ -z "$username" ]]; then
        echo "Username cannot be empty"
        return 1
    fi
    
    # Check length
    if [[ ${#username} -lt $min_length ]]; then
        echo "Username must be at least $min_length characters"
        return 1
    fi
    
    if [[ ${#username} -gt $max_length ]]; then
        echo "Username must not exceed $max_length characters"
        return 1
    fi
    
    # Check for valid characters (alphanumeric, underscore, hyphen)
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Username can only contain letters, numbers, underscore, and hyphen"
        return 1
    fi
    
    # Username should not start with hyphen or underscore
    if [[ "$username" =~ ^[-_] ]]; then
        echo "Username cannot start with hyphen or underscore"
        return 1
    fi
    
    # Check if username already exists in system
    if id "$username" &>/dev/null; then
        echo "Username already exists in system"
        return 1
    fi
    
    return 0
}

# Validate password
validate_password() {
    local password="$1"
    local min_length="${2:-8}"
    local max_length="${3:-128}"
    local require_special="${4:-false}"
    
    # Check if password is provided
    if [[ -z "$password" ]]; then
        echo "Password cannot be empty"
        return 1
    fi
    
    # Check length
    if [[ ${#password} -lt $min_length ]]; then
        echo "Password must be at least $min_length characters"
        return 1
    fi
    
    if [[ ${#password} -gt $max_length ]]; then
        echo "Password must not exceed $max_length characters"
        return 1
    fi
    
    # Check for special characters if required
    if [[ "$require_special" == "true" ]]; then
        if [[ ! "$password" =~ [[:punct:]] ]]; then
            echo "Password must contain at least one special character"
            return 1
        fi
    fi
    
    # Check for at least one digit
    if [[ ! "$password" =~ [0-9] ]]; then
        echo "Password must contain at least one digit"
        return 1
    fi
    
    # Check for at least one letter
    if [[ ! "$password" =~ [a-zA-Z] ]]; then
        echo "Password must contain at least one letter"
        return 1
    fi
    
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    local allow_privileged="${2:-false}"
    
    # Check if port is provided
    if [[ -z "$port" ]]; then
        echo "Port number cannot be empty"
        return 1
    fi
    
    # Check if port is numeric
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Port must be a number"
        return 1
    fi
    
    # Check port range
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        echo "Port must be between 1 and 65535"
        return 1
    fi
    
    # Check privileged ports
    if [[ "$allow_privileged" == "false" && $port -lt 1024 ]]; then
        echo "Privileged ports (1-1023) not allowed"
        return 1
    fi
    
    # Check if port is already in use
    if netstat -tuln | grep -q ":$port "; then
        echo "Port $port is already in use"
        return 1
    fi
    
    return 0
}

# Validate IP address
validate_ip_address() {
    local ip="$1"
    local allow_private="${2:-true}"
    
    # Check if IP is provided
    if [[ -z "$ip" ]]; then
        echo "IP address cannot be empty"
        return 1
    fi
    
    # Basic IP format validation
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! $ip =~ $regex ]]; then
        echo "Invalid IP address format"
        return 1
    fi
    
    # Check each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]]; then
            echo "Invalid IP address: octet $octet is greater than 255"
            return 1
        fi
    done
    
    # Check for private IP ranges if not allowed
    if [[ "$allow_private" == "false" ]]; then
        if [[ "$ip" =~ ^10\. ]] || \
           [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] || \
           [[ "$ip" =~ ^192\.168\. ]]; then
            echo "Private IP addresses not allowed"
            return 1
        fi
    fi
    
    return 0
}

# Validate domain name
validate_domain() {
    local domain="$1"
    local require_dns="${2:-false}"
    
    # Check if domain is provided
    if [[ -z "$domain" ]]; then
        echo "Domain cannot be empty"
        return 1
    fi
    
    # Check domain format
    local regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    if [[ ! "$domain" =~ $regex ]]; then
        echo "Invalid domain format"
        return 1
    fi
    
    # Check domain length
    if [[ ${#domain} -gt 253 ]]; then
        echo "Domain name too long (max 253 characters)"
        return 1
    fi
    
    # Check if DNS resolution is required
    if [[ "$require_dns" == "true" ]]; then
        if ! nslookup "$domain" &>/dev/null; then
            echo "Domain does not resolve to any IP address"
            return 1
        fi
    fi
    
    return 0
}

# Validate email address
validate_email() {
    local email="$1"
    
    # Check if email is provided
    if [[ -z "$email" ]]; then
        echo "Email cannot be empty"
        return 1
    fi
    
    # Basic email format validation
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if [[ ! "$email" =~ $regex ]]; then
        echo "Invalid email format"
        return 1
    fi
    
    return 0
}

# Validate UUID
validate_uuid() {
    local uuid="$1"
    
    # Check if UUID is provided
    if [[ -z "$uuid" ]]; then
        echo "UUID cannot be empty"
        return 1
    fi
    
    # UUID format validation
    local regex='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if [[ ! "$uuid" =~ $regex ]]; then
        echo "Invalid UUID format"
        return 1
    fi
    
    return 0
}

# Validate file path
validate_file_path() {
    local file_path="$1"
    local must_exist="${2:-false}"
    local must_be_writable="${3:-false}"
    
    # Check if path is provided
    if [[ -z "$file_path" ]]; then
        echo "File path cannot be empty"
        return 1
    fi
    
    # Check if file must exist
    if [[ "$must_exist" == "true" && ! -f "$file_path" ]]; then
        echo "File does not exist: $file_path"
        return 1
    fi
    
    # Check if file must be writable
    if [[ "$must_be_writable" == "true" ]]; then
        if [[ -f "$file_path" && ! -w "$file_path" ]]; then
            echo "File is not writable: $file_path"
            return 1
        fi
        
        # Check if directory is writable for new files
        local dir_path=$(dirname "$file_path")
        if [[ ! -w "$dir_path" ]]; then
            echo "Directory is not writable: $dir_path"
            return 1
        fi
    fi
    
    return 0
}

# Validate directory path
validate_directory_path() {
    local dir_path="$1"
    local must_exist="${2:-false}"
    local must_be_writable="${3:-false}"
    
    # Check if path is provided
    if [[ -z "$dir_path" ]]; then
        echo "Directory path cannot be empty"
        return 1
    fi
    
    # Check if directory must exist
    if [[ "$must_exist" == "true" && ! -d "$dir_path" ]]; then
        echo "Directory does not exist: $dir_path"
        return 1
    fi
    
    # Check if directory must be writable
    if [[ "$must_be_writable" == "true" && -d "$dir_path" && ! -w "$dir_path" ]]; then
        echo "Directory is not writable: $dir_path"
        return 1
    fi
    
    return 0
}

# Validate numeric value
validate_numeric() {
    local value="$1"
    local min_value="${2}"
    local max_value="${3}"
    
    # Check if value is provided
    if [[ -z "$value" ]]; then
        echo "Numeric value cannot be empty"
        return 1
    fi
    
    # Check if value is numeric
    if [[ ! "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Value must be numeric"
        return 1
    fi
    
    # Check minimum value
    if [[ -n "$min_value" && $(echo "$value < $min_value" | bc -l) -eq 1 ]]; then
        echo "Value must be at least $min_value"
        return 1
    fi
    
    # Check maximum value
    if [[ -n "$max_value" && $(echo "$value > $max_value" | bc -l) -eq 1 ]]; then
        echo "Value must not exceed $max_value"
        return 1
    fi
    
    return 0
}

# Validate expiry date
validate_expiry_date() {
    local expiry_date="$1"
    local format="${2:-YYYY-MM-DD}"
    
    # Check if date is provided
    if [[ -z "$expiry_date" ]]; then
        echo "Expiry date cannot be empty"
        return 1
    fi
    
    # Validate date format
    case "$format" in
        "YYYY-MM-DD")
            if [[ ! "$expiry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                echo "Invalid date format. Expected: YYYY-MM-DD"
                return 1
            fi
            ;;
        "DD-MM-YYYY")
            if [[ ! "$expiry_date" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
                echo "Invalid date format. Expected: DD-MM-YYYY"
                return 1
            fi
            ;;
        *)
            echo "Unsupported date format: $format"
            return 1
            ;;
    esac
    
    # Check if date is valid
    if ! date -d "$expiry_date" &>/dev/null; then
        echo "Invalid date: $expiry_date"
        return 1
    fi
    
    # Check if date is in the future
    local current_date=$(date +%Y-%m-%d)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp=$(date -d "$current_date" +%s)
    
    if [[ $expiry_timestamp -le $current_timestamp ]]; then
        echo "Expiry date must be in the future"
        return 1
    fi
    
    return 0
}

# Validate JSON format
validate_json() {
    local json_string="$1"
    
    # Check if JSON is provided
    if [[ -z "$json_string" ]]; then
        echo "JSON string cannot be empty"
        return 1
    fi
    
    # Check JSON syntax
    if ! echo "$json_string" | jq . &>/dev/null; then
        echo "Invalid JSON format"
        return 1
    fi
    
    return 0
}

# Validate configuration file
validate_config_file() {
    local config_file="$1"
    local required_keys=("${@:2}")
    
    # Check if file exists
    if ! validate_file_path "$config_file" true; then
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$config_file" ]]; then
        echo "Configuration file is not readable: $config_file"
        return 1
    fi
    
    # If required keys are specified, check for them
    if [[ ${#required_keys[@]} -gt 0 ]]; then
        for key in "${required_keys[@]}"; do
            if ! grep -q "^$key=" "$config_file"; then
                echo "Required configuration key missing: $key"
                return 1
            fi
        done
    fi
    
    return 0
}

# Comprehensive validation for user input
validate_user_input() {
    local input_type="$1"
    local input_value="$2"
    shift 2
    local additional_params=("$@")
    
    case "$input_type" in
        "username")
            validate_username "$input_value" "${additional_params[@]}"
            ;;
        "password")
            validate_password "$input_value" "${additional_params[@]}"
            ;;
        "port")
            validate_port "$input_value" "${additional_params[@]}"
            ;;
        "ip")
            validate_ip_address "$input_value" "${additional_params[@]}"
            ;;
        "domain")
            validate_domain "$input_value" "${additional_params[@]}"
            ;;
        "email")
            validate_email "$input_value"
            ;;
        "uuid")
            validate_uuid "$input_value"
            ;;
        "file")
            validate_file_path "$input_value" "${additional_params[@]}"
            ;;
        "directory")
            validate_directory_path "$input_value" "${additional_params[@]}"
            ;;
        "numeric")
            validate_numeric "$input_value" "${additional_params[@]}"
            ;;
        "date")
            validate_expiry_date "$input_value" "${additional_params[@]}"
            ;;
        "json")
            validate_json "$input_value"
            ;;
        *)
            echo "Unknown validation type: $input_type"
            return 1
            ;;
    esac
}

# Export functions
export -f validate_username validate_password validate_port validate_ip_address
export -f validate_domain validate_email validate_uuid validate_file_path
export -f validate_directory_path validate_numeric validate_expiry_date
export -f validate_json validate_config_file validate_user_input