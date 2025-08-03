#!/bin/bash

# Xray Manager Script
# Manages Xray services with new naming convention and separate JSON files

set -e

# Configuration paths
VMESS_CONFIG="/etc/xray/vmess.json"
VLESS_CONFIG="/etc/xray/vless.json"
TROJAN_CONFIG="/etc/xray/trojan.json"
OUTBOUNDS_CONFIG="/etc/xray/outbounds.json"
RULES_CONFIG="/etc/xray/rules.json"

# Service names
SPECTRUM_SERVICE="spectrum.service"
QUANTIX_SERVICE="quantix.service"
CIPHERON_SERVICE="cipheron.service"

# Source common utilities
if [[ -f "/opt/autoscript/utils/common.sh" ]]; then
    source "/opt/autoscript/utils/common.sh"
else
    echo "Error: Common utilities not found"
    exit 1
fi

# Check if running as root
check_root

# Function to validate Xray configuration
validate_xray_config() {
    local config_file="$1"
    local service_name="$2"
    
    echo "Validating $service_name configuration..."
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "Error: Invalid JSON syntax in $config_file"
        return 1
    fi
    
    # Test Xray configuration
    if command_exists xray; then
        if xray test -c "$config_file" &>/dev/null; then
            echo "✓ $service_name configuration is valid"
            return 0
        else
            echo "✗ $service_name configuration validation failed"
            return 1
        fi
    else
        echo "Warning: Xray not found, skipping configuration test"
        return 0
    fi
}

# Function to start Xray service
start_xray_service() {
    local service_name="$1"
    local config_file="$2"
    
    echo "Starting $service_name..."
    
    # Validate configuration first
    if ! validate_xray_config "$config_file" "$service_name"; then
        echo "Error: Configuration validation failed for $service_name"
        return 1
    fi
    
    # Start the service
    if systemctl start "$service_name" &>/dev/null; then
        echo "✓ $service_name started successfully"
        return 0
    else
        echo "✗ Failed to start $service_name"
        return 1
    fi
}

# Function to stop Xray service
stop_xray_service() {
    local service_name="$1"
    
    echo "Stopping $service_name..."
    
    if systemctl stop "$service_name" &>/dev/null; then
        echo "✓ $service_name stopped successfully"
        return 0
    else
        echo "✗ Failed to stop $service_name"
        return 1
    fi
}

# Function to restart Xray service
restart_xray_service() {
    local service_name="$1"
    local config_file="$2"
    
    echo "Restarting $service_name..."
    
    # Stop the service
    stop_xray_service "$service_name"
    
    # Start the service
    start_xray_service "$service_name" "$config_file"
}

# Function to enable Xray service
enable_xray_service() {
    local service_name="$1"
    
    echo "Enabling $service_name..."
    
    if systemctl enable "$service_name" &>/dev/null; then
        echo "✓ $service_name enabled successfully"
        return 0
    else
        echo "✗ Failed to enable $service_name"
        return 1
    fi
}

# Function to disable Xray service
disable_xray_service() {
    local service_name="$1"
    
    echo "Disabling $service_name..."
    
    if systemctl disable "$service_name" &>/dev/null; then
        echo "✓ $service_name disabled successfully"
        return 0
    else
        echo "✗ Failed to disable $service_name"
        return 1
    fi
}

# Function to check service status
check_service_status() {
    local service_name="$1"
    
    echo "Checking $service_name status..."
    
    if systemctl is-active --quiet "$service_name"; then
        echo "✓ $service_name is running"
        return 0
    else
        echo "✗ $service_name is not running"
        return 1
    fi
}

# Function to install systemd services
install_systemd_services() {
    echo "Installing systemd services..."
    
    # Copy service files
    local service_files=(
        "spectrum.service:/etc/systemd/system/spectrum.service"
        "quantix.service:/etc/systemd/system/quantix.service"
        "cipheron.service:/etc/systemd/system/cipheron.service"
    )
    
    for service_file in "${service_files[@]}"; do
        local source_file="${service_file%%:*}"
        local dest_file="${service_file##*:}"
        
        if [[ -f "systemd/$source_file" ]]; then
            cp "systemd/$source_file" "$dest_file"
            echo "✓ Installed $source_file"
        else
            echo "✗ Source file not found: systemd/$source_file"
            return 1
        fi
    done
    
    # Reload systemd
    systemctl daemon-reload
    
    echo "✓ Systemd services installed successfully"
    return 0
}

# Function to copy configuration files
copy_config_files() {
    echo "Copying configuration files..."
    
    # Create Xray config directory
    mkdir -p /etc/xray
    
    # Copy configuration files
    local config_files=(
        "config/vmess.json:/etc/xray/vmess.json"
        "config/vless.json:/etc/xray/vless.json"
        "config/trojan.json:/etc/xray/trojan.json"
        "config/outbounds.json:/etc/xray/outbounds.json"
        "config/rules.json:/etc/xray/rules.json"
    )
    
    for config_file in "${config_files[@]}"; do
        local source_file="${config_file%%:*}"
        local dest_file="${config_file##*:}"
        
        if [[ -f "$source_file" ]]; then
            cp "$source_file" "$dest_file"
            chmod 644 "$dest_file"
            echo "✓ Copied $source_file"
        else
            echo "✗ Source file not found: $source_file"
            return 1
        fi
    done
    
    echo "✓ Configuration files copied successfully"
    return 0
}

# Function to merge configuration files
merge_config_files() {
    local main_config="$1"
    local outbounds_config="$2"
    local rules_config="$3"
    local merged_config="$4"
    
    echo "Merging configuration files..."
    
    # Create temporary files
    local temp_main=$(mktemp)
    local temp_outbounds=$(mktemp)
    local temp_rules=$(mktemp)
    
    # Extract outbounds and rules
    jq '.outbounds' "$outbounds_config" > "$temp_outbounds"
    jq '.routing' "$rules_config" > "$temp_rules"
    
    # Merge configurations
    jq --argjson outbounds "$(cat "$temp_outbounds")" \
       --argjson routing "$(cat "$temp_rules")" \
       '. + {outbounds: $outbounds, routing: $routing}' "$main_config" > "$merged_config"
    
    # Cleanup
    rm -f "$temp_main" "$temp_outbounds" "$temp_rules"
    
    echo "✓ Configuration files merged successfully"
    return 0
}

# Function to setup all Xray services
setup_xray_services() {
    echo "Setting up Xray services..."
    
    # Install systemd services
    if ! install_systemd_services; then
        echo "Error: Failed to install systemd services"
        return 1
    fi
    
    # Copy configuration files
    if ! copy_config_files; then
        echo "Error: Failed to copy configuration files"
        return 1
    fi
    
    # Enable services
    enable_xray_service "$SPECTRUM_SERVICE"
    enable_xray_service "$QUANTIX_SERVICE"
    enable_xray_service "$CIPHERON_SERVICE"
    
    echo "✓ Xray services setup completed"
    return 0
}

# Function to start all services
start_all_services() {
    echo "Starting all Xray services..."
    
    local services=(
        "$SPECTRUM_SERVICE:$VMESS_CONFIG"
        "$QUANTIX_SERVICE:$VLESS_CONFIG"
        "$CIPHERON_SERVICE:$TROJAN_CONFIG"
    )
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local config_file="${service##*:}"
        
        start_xray_service "$service_name" "$config_file"
    done
    
    echo "✓ All services started"
    return 0
}

# Function to stop all services
stop_all_services() {
    echo "Stopping all Xray services..."
    
    local services=("$SPECTRUM_SERVICE" "$QUANTIX_SERVICE" "$CIPHERON_SERVICE")
    
    for service in "${services[@]}"; do
        stop_xray_service "$service"
    done
    
    echo "✓ All services stopped"
    return 0
}

# Function to restart all services
restart_all_services() {
    echo "Restarting all Xray services..."
    
    local services=(
        "$SPECTRUM_SERVICE:$VMESS_CONFIG"
        "$QUANTIX_SERVICE:$VLESS_CONFIG"
        "$CIPHERON_SERVICE:$TROJAN_CONFIG"
    )
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local config_file="${service##*:}"
        
        restart_xray_service "$service_name" "$config_file"
    done
    
    echo "✓ All services restarted"
    return 0
}

# Function to check all services status
check_all_services_status() {
    echo "Checking all Xray services status..."
    
    local services=("$SPECTRUM_SERVICE" "$QUANTIX_SERVICE" "$CIPHERON_SERVICE")
    
    for service in "${services[@]}"; do
        check_service_status "$service"
    done
    
    echo "✓ Status check completed"
    return 0
}

# Show usage
show_usage() {
    echo "Xray Manager Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                    - Setup all Xray services"
    echo "  start [service]          - Start service(s)"
    echo "  stop [service]           - Stop service(s)"
    echo "  restart [service]        - Restart service(s)"
    echo "  status [service]         - Check service status"
    echo "  enable [service]         - Enable service(s)"
    echo "  disable [service]        - Disable service(s)"
    echo "  validate [service]       - Validate configuration"
    echo ""
    echo "Services:"
    echo "  spectrum                 - VMess service"
    echo "  quantix                  - VLESS service"
    echo "  cipheron                 - Trojan service"
    echo "  all                      - All services"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 start spectrum"
    echo "  $0 restart all"
    echo "  $0 status quantix"
    echo "  $0 validate cipheron"
}

# Main function
main() {
    local command="$1"
    local service="$2"
    
    case "$command" in
        "setup")
            setup_xray_services
            ;;
        "start")
            case "$service" in
                "spectrum")
                    start_xray_service "$SPECTRUM_SERVICE" "$VMESS_CONFIG"
                    ;;
                "quantix")
                    start_xray_service "$QUANTIX_SERVICE" "$VLESS_CONFIG"
                    ;;
                "cipheron")
                    start_xray_service "$CIPHERON_SERVICE" "$TROJAN_CONFIG"
                    ;;
                "all")
                    start_all_services
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "stop")
            case "$service" in
                "spectrum")
                    stop_xray_service "$SPECTRUM_SERVICE"
                    ;;
                "quantix")
                    stop_xray_service "$QUANTIX_SERVICE"
                    ;;
                "cipheron")
                    stop_xray_service "$CIPHERON_SERVICE"
                    ;;
                "all")
                    stop_all_services
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "restart")
            case "$service" in
                "spectrum")
                    restart_xray_service "$SPECTRUM_SERVICE" "$VMESS_CONFIG"
                    ;;
                "quantix")
                    restart_xray_service "$QUANTIX_SERVICE" "$VLESS_CONFIG"
                    ;;
                "cipheron")
                    restart_xray_service "$CIPHERON_SERVICE" "$TROJAN_CONFIG"
                    ;;
                "all")
                    restart_all_services
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "status")
            case "$service" in
                "spectrum")
                    check_service_status "$SPECTRUM_SERVICE"
                    ;;
                "quantix")
                    check_service_status "$QUANTIX_SERVICE"
                    ;;
                "cipheron")
                    check_service_status "$CIPHERON_SERVICE"
                    ;;
                "all")
                    check_all_services_status
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "enable")
            case "$service" in
                "spectrum")
                    enable_xray_service "$SPECTRUM_SERVICE"
                    ;;
                "quantix")
                    enable_xray_service "$QUANTIX_SERVICE"
                    ;;
                "cipheron")
                    enable_xray_service "$CIPHERON_SERVICE"
                    ;;
                "all")
                    enable_xray_service "$SPECTRUM_SERVICE"
                    enable_xray_service "$QUANTIX_SERVICE"
                    enable_xray_service "$CIPHERON_SERVICE"
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "disable")
            case "$service" in
                "spectrum")
                    disable_xray_service "$SPECTRUM_SERVICE"
                    ;;
                "quantix")
                    disable_xray_service "$QUANTIX_SERVICE"
                    ;;
                "cipheron")
                    disable_xray_service "$CIPHERON_SERVICE"
                    ;;
                "all")
                    disable_xray_service "$SPECTRUM_SERVICE"
                    disable_xray_service "$QUANTIX_SERVICE"
                    disable_xray_service "$CIPHERON_SERVICE"
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        "validate")
            case "$service" in
                "spectrum")
                    validate_xray_config "$VMESS_CONFIG" "Spectrum"
                    ;;
                "quantix")
                    validate_xray_config "$VLESS_CONFIG" "Quantix"
                    ;;
                "cipheron")
                    validate_xray_config "$TROJAN_CONFIG" "Cipheron"
                    ;;
                "all")
                    validate_xray_config "$VMESS_CONFIG" "Spectrum"
                    validate_xray_config "$VLESS_CONFIG" "Quantix"
                    validate_xray_config "$TROJAN_CONFIG" "Cipheron"
                    ;;
                *)
                    echo "Error: Unknown service: $service"
                    show_usage
                    exit 1
                    ;;
            esac
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