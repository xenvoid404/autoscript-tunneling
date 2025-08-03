#!/bin/bash

# Xray Client Management Script
# Manages clients across separated VMess, VLESS, and Trojan services

set -e

# Configuration paths
VMESS_CONFIG="/etc/xray/vmess.json"
VLESS_CONFIG="/etc/xray/vless.json"
TROJAN_CONFIG="/etc/xray/trojan.json"

# Source common utilities
if [[ -f "/opt/autoscript/utils/common.sh" ]]; then
    source "/opt/autoscript/utils/common.sh"
else
    echo "Error: Common utilities not found"
    exit 1
fi

# Check if running as root
check_root

# Generate UUID for client
generate_client_id() {
    generate_uuid
}

# Generate random password for Trojan
generate_trojan_password() {
    generate_random_string 32
}

# Add client to VMess service
add_vmess_client() {
    local username="$1"
    local client_id="${2:-$(generate_client_id)}"
    
    echo "Adding VMess client: $username"
    
    # Create client entry
    local client_entry=$(cat << EOF
{
    "id": "$client_id",
    "email": "$username@vmess"
}
EOF
    )
    
    # Add to configuration
    local temp_file=$(mktemp)
    jq --argjson client "$client_entry" '.inbounds[].settings.clients += [$client]' "$VMESS_CONFIG" > "$temp_file"
    mv "$temp_file" "$VMESS_CONFIG"
    
    echo "VMess client added successfully"
    echo "Client ID: $client_id"
    
    # Restart VMess service
    restart_service "spectrum"
    
    return 0
}

# Add client to VLESS service
add_vless_client() {
    local username="$1"
    local client_id="${2:-$(generate_client_id)}"
    
    echo "Adding VLESS client: $username"
    
    # Create client entry
    local client_entry=$(cat << EOF
{
    "id": "$client_id",
    "email": "$username@vless"
}
EOF
    )
    
    # Add to configuration
    local temp_file=$(mktemp)
    jq --argjson client "$client_entry" '.inbounds[].settings.clients += [$client]' "$VLESS_CONFIG" > "$temp_file"
    mv "$temp_file" "$VLESS_CONFIG"
    
    echo "VLESS client added successfully"
    echo "Client ID: $client_id"
    
    # Restart VLESS service
    restart_service "quantix"
    
    return 0
}

# Add client to Trojan service
add_trojan_client() {
    local username="$1"
    local password="${2:-$(generate_trojan_password)}"
    
    echo "Adding Trojan client: $username"
    
    # Create client entry
    local client_entry=$(cat << EOF
{
    "password": "$password",
    "email": "$username@trojan"
}
EOF
    )
    
    # Add to configuration
    local temp_file=$(mktemp)
    jq --argjson client "$client_entry" '.inbounds[].settings.clients += [$client]' "$TROJAN_CONFIG" > "$temp_file"
    mv "$temp_file" "$TROJAN_CONFIG"
    
    echo "Trojan client added successfully"
    echo "Password: $password"
    
    # Restart Trojan service
    restart_service "cipheron"
    
    return 0
}

# Remove client from service
remove_client() {
    local protocol="$1"
    local username="$2"
    
    case "$protocol" in
        "vmess")
            local config_file="$VMESS_CONFIG"
            local service_name="xray-vmess"
            ;;
        "vless")
            local config_file="$VLESS_CONFIG"
            local service_name="xray-vless"
            ;;
        "trojan")
            local config_file="$TROJAN_CONFIG"
            local service_name="xray-trojan"
            ;;
        *)
            echo "Error: Unknown protocol: $protocol"
            return 1
            ;;
    esac
    
    echo "Removing $protocol client: $username"
    
    # Remove client from configuration
    local temp_file=$(mktemp)
    jq --arg email "$username@$protocol" '.inbounds[].settings.clients = [.inbounds[].settings.clients[] | select(.email != $email)]' "$config_file" > "$temp_file"
    mv "$temp_file" "$config_file"
    
    echo "$protocol client removed successfully"
    
    # Restart service
    restart_service "$service_name"
    
    return 0
}

# List all clients
list_clients() {
    echo "=== VMess Clients ==="
    if [[ -f "$VMESS_CONFIG" ]]; then
        jq -r '.inbounds[].settings.clients[]? | "\(.email // "unknown") - \(.id)"' "$VMESS_CONFIG" 2>/dev/null || echo "No VMess clients found"
    else
        echo "VMess configuration not found"
    fi
    
    echo ""
    echo "=== VLESS Clients ==="
    if [[ -f "$VLESS_CONFIG" ]]; then
        jq -r '.inbounds[].settings.clients[]? | "\(.email // "unknown") - \(.id)"' "$VLESS_CONFIG" 2>/dev/null || echo "No VLESS clients found"
    else
        echo "VLESS configuration not found"
    fi
    
    echo ""
    echo "=== Trojan Clients ==="
    if [[ -f "$TROJAN_CONFIG" ]]; then
        jq -r '.inbounds[].settings.clients[]? | "\(.email // "unknown") - \(.password)"' "$TROJAN_CONFIG" 2>/dev/null || echo "No Trojan clients found"
    else
        echo "Trojan configuration not found"
    fi
}

# Generate client configuration
generate_client_config() {
    local protocol="$1"
    local username="$2"
    local server_ip="${3:-$(get_public_ip)}"
    
    case "$protocol" in
        "vmess")
            generate_vmess_config "$username" "$server_ip"
            ;;
        "vless")
            generate_vless_config "$username" "$server_ip"
            ;;
        "trojan")
            generate_trojan_config "$username" "$server_ip"
            ;;
        *)
            echo "Error: Unknown protocol: $protocol"
            return 1
            ;;
    esac
}

# Generate VMess configuration
generate_vmess_config() {
    local username="$1"
    local server_ip="$2"
    
    # Get client ID from configuration
    local client_id=$(jq -r --arg email "$username@vmess" '.inbounds[].settings.clients[] | select(.email == $email) | .id' "$VMESS_CONFIG" 2>/dev/null)
    
    if [[ -z "$client_id" ]]; then
        echo "Error: VMess client not found: $username"
        return 1
    fi
    
    echo "VMess Configuration for $username:"
    echo "=================================="
    echo "Server: $server_ip"
    echo "Port: 55 (WebSocket)"
    echo "UUID: $client_id"
    echo "Path: /vmess"
    echo "Network: ws"
    echo "Security: none"
    echo ""
    echo "Alternative ports:"
    echo "- gRPC: 1054"
    echo "- TCP: 1055"
}

# Generate VLESS configuration
generate_vless_config() {
    local username="$1"
    local server_ip="$2"
    
    # Get client ID from configuration
    local client_id=$(jq -r --arg email "$username@vless" '.inbounds[].settings.clients[] | select(.email == $email) | .id' "$VLESS_CONFIG" 2>/dev/null)
    
    if [[ -z "$client_id" ]]; then
        echo "Error: VLESS client not found: $username"
        return 1
    fi
    
    echo "VLESS Configuration for $username:"
    echo "=================================="
    echo "Server: $server_ip"
    echo "Port: 58 (WebSocket)"
    echo "UUID: $client_id"
    echo "Path: /vless"
    echo "Network: ws"
    echo "Security: none"
    echo ""
    echo "Alternative ports:"
    echo "- gRPC: 1057"
    echo "- TCP: 1058"
}

# Generate Trojan configuration
generate_trojan_config() {
    local username="$1"
    local server_ip="$2"
    
    # Get client password from configuration
    local password=$(jq -r --arg email "$username@trojan" '.inbounds[].settings.clients[] | select(.email == $email) | .password' "$TROJAN_CONFIG" 2>/dev/null)
    
    if [[ -z "$password" ]]; then
        echo "Error: Trojan client not found: $username"
        return 1
    fi
    
    echo "Trojan Configuration for $username:"
    echo "==================================="
    echo "Server: $server_ip"
    echo "Port: 1060 (WebSocket)"
    echo "Password: $password"
    echo "Path: /trojan"
    echo "Network: ws"
    echo "Security: none"
    echo ""
    echo "Alternative ports:"
    echo "- gRPC: 1061"
    echo "- TCP: 1059"
}

# Show usage
show_usage() {
    echo "Xray Client Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add <protocol> <username> [id/password]  - Add new client"
    echo "  remove <protocol> <username>             - Remove client"
    echo "  list                                     - List all clients"
    echo "  config <protocol> <username> [server_ip] - Generate client config"
    echo ""
    echo "Protocols:"
    echo "  vmess   - VMess protocol"
    echo "  vless   - VLESS protocol"
    echo "  trojan  - Trojan protocol"
    echo ""
    echo "Examples:"
    echo "  $0 add vmess john"
    echo "  $0 add trojan jane mypassword123"
    echo "  $0 remove vless john"
    echo "  $0 list"
    echo "  $0 config vmess john 1.2.3.4"
}

# Main function
main() {
    local command="$1"
    
    case "$command" in
        "add")
            local protocol="$2"
            local username="$3"
            local credential="$4"
            
            if [[ -z "$protocol" ]] || [[ -z "$username" ]]; then
                echo "Error: Protocol and username are required"
                show_usage
                exit 1
            fi
            
            case "$protocol" in
                "vmess")
                    add_vmess_client "$username" "$credential"
                    ;;
                "vless")
                    add_vless_client "$username" "$credential"
                    ;;
                "trojan")
                    add_trojan_client "$username" "$credential"
                    ;;
                *)
                    echo "Error: Unknown protocol: $protocol"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "remove")
            local protocol="$2"
            local username="$3"
            
            if [[ -z "$protocol" ]] || [[ -z "$username" ]]; then
                echo "Error: Protocol and username are required"
                show_usage
                exit 1
            fi
            
            remove_client "$protocol" "$username"
            ;;
        "list")
            list_clients
            ;;
        "config")
            local protocol="$2"
            local username="$3"
            local server_ip="$4"
            
            if [[ -z "$protocol" ]] || [[ -z "$username" ]]; then
                echo "Error: Protocol and username are required"
                show_usage
                exit 1
            fi
            
            generate_client_config "$protocol" "$username" "$server_ip"
            ;;
        *)
            echo "Error: Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check if jq is installed
if ! command_exists jq; then
    echo "Error: jq is required but not installed"
    echo "Please install jq: apt-get install jq"
    exit 1
fi

# Run main function
main "$@"