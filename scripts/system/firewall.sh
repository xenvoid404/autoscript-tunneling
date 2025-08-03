#!/bin/bash

# Firewall configuration script for Modern Tunneling Autoscript
# Configures UFW firewall with secure rules for tunneling services

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/config/system.conf"

# Initialize logging
init_logging

# Function to install UFW if not present
install_ufw() {
    log_function_start "install_ufw"
    
    if ! command_exists ufw; then
        print_info "Installing UFW firewall..."
        if install_package "ufw"; then
            print_success "UFW installed successfully"
            log_info "UFW firewall installed"
        else
            print_error "Failed to install UFW"
            return 1
        fi
    else
        print_info "UFW already installed"
    fi
    
    log_function_end "install_ufw" 0
    return 0
}

# Function to configure basic firewall rules
configure_basic_rules() {
    log_function_start "configure_basic_rules"
    
    print_section "Configuring Basic Firewall Rules"
    
    # Reset UFW to defaults
    print_info "Resetting UFW to defaults..."
    ufw --force reset &>/dev/null
    
    # Set default policies
    print_info "Setting default policies..."
    ufw default deny incoming &>/dev/null
    ufw default allow outgoing &>/dev/null
    
    print_success "Basic rules configured"
    log_info "UFW basic rules configured"
    
    log_function_end "configure_basic_rules" 0
    return 0
}

# Function to configure SSH rules
configure_ssh_rules() {
    log_function_start "configure_ssh_rules"
    
    print_section "Configuring SSH Rules"
    
    # Allow SSH port
    if [[ "$ENABLE_SSH" == "true" ]]; then
        print_info "Allowing SSH on port $SSH_PORT..."
        ufw allow "$SSH_PORT/tcp" comment "OpenSSH" &>/dev/null
        print_success "SSH port $SSH_PORT allowed"
    fi
    
    # Allow Dropbear ports
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        print_info "Allowing Dropbear on port $DROPBEAR_PORT..."
        ufw allow "$DROPBEAR_PORT/tcp" comment "Dropbear SSH" &>/dev/null
        print_success "Dropbear port $DROPBEAR_PORT allowed"
        
        print_info "Allowing Dropbear WebSocket on port $DROPBEAR_PORT_WS..."
        ufw allow "$DROPBEAR_PORT_WS/tcp" comment "Dropbear WebSocket" &>/dev/null
        print_success "Dropbear WebSocket port $DROPBEAR_PORT_WS allowed"
    fi
    
    # Allow SSH WebSocket port
    print_info "Allowing SSH WebSocket on port $WEBSOCKET_PORT..."
    ufw allow "$WEBSOCKET_PORT/tcp" comment "SSH WebSocket" &>/dev/null
    print_success "SSH WebSocket port $WEBSOCKET_PORT allowed"
    
    log_function_end "configure_ssh_rules" 0
    return 0
}

# Function to configure Xray rules
configure_xray_rules() {
    log_function_start "configure_xray_rules"
    
    if [[ "$ENABLE_XRAY" != "true" ]]; then
        log_info "Xray firewall rules skipped (disabled in config)"
        return 0
    fi
    
    print_section "Configuring Xray Rules"
    
    # Allow Xray ports
    print_info "Allowing Xray VMess/VLESS on port $XRAY_VMESS_PORT..."
    ufw allow "$XRAY_VMESS_PORT/tcp" comment "Xray VMess/VLESS" &>/dev/null
    print_success "Xray port $XRAY_VMESS_PORT allowed"
    
    print_info "Allowing Xray TLS on port $XRAY_VMESS_TLS_PORT..."
    ufw allow "$XRAY_VMESS_TLS_PORT/tcp" comment "Xray TLS" &>/dev/null
    print_success "Xray TLS port $XRAY_VMESS_TLS_PORT allowed"
    
    print_info "Allowing Xray Trojan on port $XRAY_TROJAN_PORT..."
    ufw allow "$XRAY_TROJAN_PORT/tcp" comment "Xray Trojan" &>/dev/null
    print_success "Xray Trojan port $XRAY_TROJAN_PORT allowed"
    
    log_function_end "configure_xray_rules" 0
    return 0
}

# Function to configure rate limiting rules
configure_rate_limiting() {
    log_function_start "configure_rate_limiting"
    
    print_section "Configuring Rate Limiting"
    
    # SSH rate limiting
    print_info "Setting up SSH rate limiting..."
    ufw limit "$SSH_PORT/tcp" comment "SSH Rate Limit" &>/dev/null
    
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        ufw limit "$DROPBEAR_PORT/tcp" comment "Dropbear Rate Limit" &>/dev/null
    fi
    
    print_success "Rate limiting configured"
    log_info "Firewall rate limiting rules applied"
    
    log_function_end "configure_rate_limiting" 0
    return 0
}

# Function to configure additional security rules
configure_security_rules() {
    log_function_start "configure_security_rules"
    
    print_section "Configuring Additional Security Rules"
    
    # Block common attack vectors
    print_info "Blocking common attack vectors..."
    
    # Block invalid packets
    ufw deny in from any to any port 0 &>/dev/null
    
    # Block NetBIOS
    ufw deny 135,137,138,139,445/tcp &>/dev/null
    ufw deny 135,137,138,139,445/udp &>/dev/null
    
    # Block SNMP
    ufw deny 161/udp &>/dev/null
    ufw deny 162/udp &>/dev/null
    
    print_success "Security rules applied"
    log_info "Additional firewall security rules configured"
    
    log_function_end "configure_security_rules" 0
    return 0
}

# Function to configure custom rules
configure_custom_rules() {
    log_function_start "configure_custom_rules"
    
    print_section "Configuring Custom Rules"
    
    # Allow ping (ICMP)
    print_info "Allowing ICMP (ping)..."
    ufw allow from any to any port 0:65535 proto icmp &>/dev/null
    
    # Allow DNS
    print_info "Allowing DNS queries..."
    ufw allow out 53/udp comment "DNS" &>/dev/null
    ufw allow out 53/tcp comment "DNS over TCP" &>/dev/null
    
    # Allow NTP
    print_info "Allowing NTP..."
    ufw allow out 123/udp comment "NTP" &>/dev/null
    
    # Allow HTTP/HTTPS for updates
    print_info "Allowing HTTP/HTTPS for updates..."
    ufw allow out 80/tcp comment "HTTP" &>/dev/null
    ufw allow out 443/tcp comment "HTTPS" &>/dev/null
    
    print_success "Custom rules configured"
    log_info "Custom firewall rules applied"
    
    log_function_end "configure_custom_rules" 0
    return 0
}

# Function to enable firewall
enable_firewall() {
    log_function_start "enable_firewall"
    
    print_section "Enabling Firewall"
    
    # Enable UFW
    print_info "Enabling UFW firewall..."
    if ufw --force enable &>/dev/null; then
        print_success "UFW firewall enabled successfully"
        log_info "UFW firewall enabled"
    else
        print_error "Failed to enable UFW firewall"
        log_error "UFW firewall enable failed"
        return 1
    fi
    
    # Enable UFW service
    if systemctl enable ufw &>/dev/null; then
        print_success "UFW service enabled for startup"
        log_info "UFW service enabled for system startup"
    else
        print_warning "Failed to enable UFW service for startup"
        log_warn "UFW service startup enable failed"
    fi
    
    log_function_end "enable_firewall" 0
    return 0
}

# Function to show firewall status
show_firewall_status() {
    print_section "Firewall Status"
    
    # Show UFW status
    echo -e "${CYAN}UFW Status:${NC}"
    ufw status verbose
    
    echo -e "\n${CYAN}Active Rules:${NC}"
    ufw status numbered
    
    echo -e "\n${CYAN}Service Status:${NC}"
    if systemctl is-active --quiet ufw; then
        echo -e "UFW Service: ${GREEN}Active${NC}"
    else
        echo -e "UFW Service: ${RED}Inactive${NC}"
    fi
    
    if systemctl is-enabled --quiet ufw; then
        echo -e "UFW Startup: ${GREEN}Enabled${NC}"
    else
        echo -e "UFW Startup: ${YELLOW}Disabled${NC}"
    fi
}

# Function to verify firewall configuration
verify_firewall() {
    log_function_start "verify_firewall"
    
    print_section "Verifying Firewall Configuration"
    
    local verification_failed=false
    
    # Check if UFW is enabled
    if ufw status | grep -q "Status: active"; then
        print_success "✓ UFW is active"
        log_info "UFW firewall verification: active"
    else
        print_error "✗ UFW is not active"
        verification_failed=true
    fi
    
    # Check essential ports
    local essential_ports=("$SSH_PORT")
    
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        essential_ports+=("$DROPBEAR_PORT" "$DROPBEAR_PORT_WS")
    fi
    
    if [[ "$ENABLE_XRAY" == "true" ]]; then
        essential_ports+=("$XRAY_VMESS_PORT" "$XRAY_VMESS_TLS_PORT")
    fi
    
    essential_ports+=("$WEBSOCKET_PORT")
    
    for port in "${essential_ports[@]}"; do
        if ufw status | grep -q "$port"; then
            print_success "✓ Port $port is allowed"
            log_debug "Firewall port $port verification passed"
        else
            print_error "✗ Port $port is not allowed"
            verification_failed=true
        fi
    done
    
    # Check service status
    if systemctl is-active --quiet ufw; then
        print_success "✓ UFW service is running"
        log_info "UFW service status verification passed"
    else
        print_error "✗ UFW service is not running"
        verification_failed=true
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        print_error "Firewall verification failed"
        log_function_end "verify_firewall" 1
        return 1
    else
        print_success "Firewall verification passed"
        log_function_end "verify_firewall" 0
        return 0
    fi
}

# Function to create firewall backup
backup_firewall_rules() {
    log_function_start "backup_firewall_rules"
    
    print_info "Creating firewall rules backup..."
    
    local backup_dir="/etc/autoscript/backup"
    local backup_file="$backup_dir/ufw_rules_$(date +%Y%m%d_%H%M%S).backup"
    
    create_directory "$backup_dir" "700"
    
    # Export UFW rules
    if ufw status numbered > "$backup_file"; then
        print_success "Firewall rules backed up to: $backup_file"
        log_info "Firewall rules backup created: $backup_file"
    else
        print_warning "Failed to create firewall backup"
        log_warn "Firewall backup creation failed"
    fi
    
    log_function_end "backup_firewall_rules" 0
}

# Main firewall configuration function
main() {
    log_function_start "main"
    
    # Check if running as root
    check_root
    
    print_banner
    print_section "Firewall Configuration"
    
    # Install UFW
    if ! install_ufw; then
        log_error "UFW installation failed"
        exit 1
    fi
    
    # Backup current rules
    backup_firewall_rules
    
    # Configure firewall rules
    if ! configure_basic_rules; then
        log_error "Basic rules configuration failed"
        exit 1
    fi
    
    if ! configure_ssh_rules; then
        log_error "SSH rules configuration failed"
        exit 1
    fi
    
    if ! configure_xray_rules; then
        log_error "Xray rules configuration failed"
    fi
    
    if ! configure_rate_limiting; then
        log_error "Rate limiting configuration failed"
    fi
    
    if ! configure_security_rules; then
        log_error "Security rules configuration failed"
    fi
    
    if ! configure_custom_rules; then
        log_error "Custom rules configuration failed"
    fi
    
    # Enable firewall
    if ! enable_firewall; then
        log_error "Firewall enable failed"
        exit 1
    fi
    
    # Verify configuration
    if ! verify_firewall; then
        log_error "Firewall verification failed"
        exit 1
    fi
    
    # Show status
    show_firewall_status
    
    print_success "Firewall configuration completed successfully"
    log_info "Firewall configuration completed"
    
    log_function_end "main" 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi