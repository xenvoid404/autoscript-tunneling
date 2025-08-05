#!/bin/bash

# Improved Certificate Installer
# Author: Xenvoid404
# Version: 2.0

# Load common functions
source lib/common.sh

# Load environment configuration
source config/environment.conf

install_certificate() {
    local install_success=false
    
    print_info "INSTALLING CERTIFICATES..."
    
    # Backup existing certificates if any
    if [ -d "$CERT_DIR" ]; then
        backup_config "$CERT_DIR"
    fi
    
    # Create certificate directory
    mkdir -p "$CERT_DIR"
    
    # Check dependencies
    if ! check_dependencies "curl" "openssl"; then
        print_error "Missing required dependencies for certificate installation"
        return 1
    fi
    
    # Download and install acme.sh
    print_info "Installing acme.sh..."
    if ! curl https://get.acme.sh | sh; then
        print_error "Failed to install acme.sh"
        rollback_installation "certificate"
        return 1
    fi
    
    # Change to acme.sh directory
    cd ~/.acme.sh || {
        print_error "Failed to change to acme.sh directory"
        rollback_installation "certificate"
        return 1
    }
    
    # Upgrade acme.sh
    print_info "Upgrading acme.sh..."
    if ! ./acme.sh --upgrade --auto-upgrade; then
        print_warning "acme.sh upgrade failed, continuing..."
    fi
    
    # Set default CA
    print_info "Setting default CA..."
    if ! ./acme.sh --set-default-ca --server letsencrypt; then
        print_error "Failed to set default CA"
        rollback_installation "certificate"
        return 1
    fi
    
    # Register account
    print_info "Registering account..."
    if ! ./acme.sh --register-account -m "$CERT_EMAIL"; then
        print_error "Failed to register account"
        rollback_installation "certificate"
        return 1
    fi
    
    # Check if domain is set
    if [ -z "$DOMAIN" ] || [ ! -f "$DOMAIN_FILE" ]; then
        print_error "Domain not configured"
        rollback_installation "certificate"
        return 1
    fi
    
    # Issue certificate
    print_info "Issuing certificate for domain: $DOMAIN"
    if ! ./acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 --force; then
        print_error "Failed to issue certificate"
        rollback_installation "certificate"
        return 1
    fi
    
    # Install certificate
    print_info "Installing certificate..."
    if ! ./acme.sh --installcert -d "$DOMAIN" \
        --fullchainpath "$CERT_DIR/fullchain.crt" \
        --keypath "$CERT_DIR/private.key" \
        --ecc; then
        print_error "Failed to install certificate"
        rollback_installation "certificate"
        return 1
    fi
    
    # Validate certificate files
    if ! validate_file "$CERT_DIR/fullchain.crt" "Certificate file"; then
        print_error "Certificate validation failed"
        rollback_installation "certificate"
        return 1
    fi
    
    if ! validate_file "$CERT_DIR/private.key" "Private key file"; then
        print_error "Private key validation failed"
        rollback_installation "certificate"
        return 1
    fi
    
    # Set proper permissions
    chmod 600 "$CERT_DIR"/*
    chown nobody:nogroup "$CERT_DIR"/*
    
    # Create combined PEM file for HAProxy
    cat "$CERT_DIR/fullchain.crt" "$CERT_DIR/private.key" > "$CERT_DIR/full.pem"
    chmod 600 "$CERT_DIR/full.pem"
    
    # Test certificate
    print_info "Testing certificate..."
    if openssl x509 -in "$CERT_DIR/fullchain.crt" -text -noout >/dev/null 2>&1; then
        print_success "Certificate is valid"
        install_success=true
    else
        print_error "Certificate validation failed"
        rollback_installation "certificate"
        return 1
    fi
    
    # Cleanup
    rm -rf ~/.acme.sh >/dev/null 2>&1
    
    if [ "$install_success" = true ]; then
        print_success "CERTIFICATES INSTALLED SUCCESSFULLY"
        return 0
    else
        print_error "Certificate installation failed"
        return 1
    fi
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_certificate
    exit $?
fi