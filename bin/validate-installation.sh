#!/bin/bash

# Validation Script untuk Autoscript Tunneling
# Author: Xenvoid404
# Version: 1.0

# Load common functions
source lib/common.sh

# Load environment configuration
source config/environment.conf

# Validation results
declare -A validation_results
validation_results["certificate"]=false
validation_results["xray"]=false
validation_results["openvpn"]=false
validation_results["ssh"]=false
validation_results["firewall"]=false

validate_certificate() {
    print_info "Validating certificate installation..."
    
    if [ ! -d "$CERT_DIR" ]; then
        print_error "Certificate directory not found"
        return 1
    fi
    
    local required_files=("fullchain.crt" "private.key" "full.pem")
    for file in "${required_files[@]}"; do
        if [ ! -f "$CERT_DIR/$file" ]; then
            print_error "Certificate file missing: $file"
            return 1
        fi
    done
    
    # Test certificate validity
    if ! openssl x509 -in "$CERT_DIR/fullchain.crt" -text -noout >/dev/null 2>&1; then
        print_error "Certificate is invalid"
        return 1
    fi
    
    # Check certificate expiration
    local expiry_date=$(openssl x509 -in "$CERT_DIR/fullchain.crt" -noout -enddate | cut -d= -f2)
    local current_date=$(date +%s)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    
    if [ $current_date -gt $expiry_timestamp ]; then
        print_error "Certificate has expired"
        return 1
    fi
    
    print_success "Certificate validation passed"
    validation_results["certificate"]=true
    return 0
}

validate_xray() {
    print_info "Validating Xray installation..."
    
    # Check if xray binary exists
    if ! command -v xray >/dev/null 2>&1; then
        print_error "Xray binary not found"
        return 1
    fi
    
    # Check service files
    for service in "${XRAY_SERVICES[@]}"; do
        if [ ! -f "/etc/systemd/system/${service}.service" ]; then
            print_error "Service file missing: ${service}.service"
            return 1
        fi
    done
    
    # Check configuration files
    if [ ! -d "/etc/default/layers" ]; then
        print_error "Xray configuration directory not found"
        return 1
    fi
    
    # Check if services are running
    for service in "${XRAY_SERVICES[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            print_warning "Service not running: $service"
        fi
    done
    
    # Test xray configuration
    if ! xray test -c /etc/default/layers/spectrum/vmess.json >/dev/null 2>&1; then
        print_error "Xray configuration test failed"
        return 1
    fi
    
    print_success "Xray validation passed"
    validation_results["xray"]=true
    return 0
}

validate_openvpn() {
    print_info "Validating OpenVPN installation..."
    
    # Check if openvpn binary exists
    if ! command -v openvpn >/dev/null 2>&1; then
        print_error "OpenVPN binary not found"
        return 1
    fi
    
    # Check configuration directory
    if [ ! -d "/etc/openvpn" ]; then
        print_error "OpenVPN configuration directory not found"
        return 1
    fi
    
    # Check configuration files
    local required_configs=("server-tcp-1194.conf" "server-udp-25000.conf")
    for config in "${required_configs[@]}"; do
        if [ ! -f "/etc/openvpn/server/$config" ]; then
            print_error "OpenVPN config missing: $config"
            return 1
        fi
    done
    
    # Check client configuration files
    local client_configs=("myvpn-tcp-80.ovpn" "myvpn-udp-25000.ovpn" "myvpn-ssl-443.ovpn")
    for config in "${client_configs[@]}"; do
        if [ ! -f "/etc/openvpn/$config" ]; then
            print_error "Client config missing: $config"
            return 1
        fi
    done
    
    # Check if services are running
    for service in "${OPENVPN_SERVICES[@]}"; do
        if ! systemctl is-active --quiet "openvpn-server@$service"; then
            print_warning "OpenVPN service not running: $service"
        fi
    done
    
    print_success "OpenVPN validation passed"
    validation_results["openvpn"]=true
    return 0
}

validate_ssh() {
    print_info "Validating SSH installation..."
    
    # Check SSH service
    if ! systemctl is-active --quiet ssh; then
        print_error "SSH service not running"
        return 1
    fi
    
    # Check SSH configuration
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        print_error "SSH configuration file not found"
        return 1
    fi
    
    # Test SSH configuration
    if ! sshd -t >/dev/null 2>&1; then
        print_error "SSH configuration test failed"
        return 1
    fi
    
    # Check Dropbear if installed
    if command -v dropbear >/dev/null 2>&1; then
        if ! systemctl is-active --quiet dropbear; then
            print_warning "Dropbear service not running"
        fi
    fi
    
    print_success "SSH validation passed"
    validation_results["ssh"]=true
    return 0
}

validate_firewall() {
    print_info "Validating firewall configuration..."
    
    # Check if iptables is installed
    if ! command -v iptables >/dev/null 2>&1; then
        print_error "iptables not found"
        return 1
    fi
    
    # Check if rules are loaded
    if ! iptables -L >/dev/null 2>&1; then
        print_error "iptables rules not loaded"
        return 1
    fi
    
    # Check if fail2ban is running
    if command -v fail2ban-client >/dev/null 2>&1; then
        if ! systemctl is-active --quiet fail2ban; then
            print_warning "fail2ban service not running"
        fi
    fi
    
    print_success "Firewall validation passed"
    validation_results["firewall"]=true
    return 0
}

validate_network() {
    print_info "Validating network configuration..."
    
    # Check IP forwarding
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
        print_error "IP forwarding not enabled"
        return 1
    fi
    
    # Check domain resolution
    if [ -f "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE")
        if ! nslookup "$domain" >/dev/null 2>&1; then
            print_warning "Domain resolution failed: $domain"
        fi
    fi
    
    print_success "Network validation passed"
    return 0
}

generate_report() {
    print_info "Generating validation report..."
    
    echo "=============================================="
    echo "           VALIDATION REPORT"
    echo "=============================================="
    echo
    
    local total_checks=0
    local passed_checks=0
    
    for service in "${!validation_results[@]}"; do
        total_checks=$((total_checks + 1))
        if [ "${validation_results[$service]}" = true ]; then
            passed_checks=$((passed_checks + 1))
            print_success "$service: PASSED"
        else
            print_error "$service: FAILED"
        fi
    done
    
    echo
    echo "=============================================="
    echo "Summary: $passed_checks/$total_checks services passed"
    echo "=============================================="
    
    if [ $passed_checks -eq $total_checks ]; then
        print_success "All services validated successfully!"
        return 0
    else
        print_error "Some services failed validation"
        return 1
    fi
}

main() {
    print_info "Starting installation validation..."
    
    validate_certificate
    validate_xray
    validate_openvpn
    validate_ssh
    validate_firewall
    validate_network
    
    generate_report
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
    exit $?
fi