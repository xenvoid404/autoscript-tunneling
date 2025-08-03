#!/bin/bash

# SSL Manager Script
# Handles SSL certificate generation and management for Xray services

set -e

# SSL configuration
SSL_DIR="/etc/xray/ssl"
SSL_CERT="$SSL_DIR/cert.pem"
SSL_KEY="$SSL_DIR/key.pem"
SSL_CA="$SSL_DIR/ca.crt"

# Source common utilities
if [[ -f "/opt/autoscript/utils/common.sh" ]]; then
    source "/opt/autoscript/utils/common.sh"
else
    echo "Error: Common utilities not found"
    exit 1
fi

# Check if running as root
check_root

# Function to generate SSL certificate
generate_ssl_certificate() {
    echo "Generating SSL certificate..."
    
    # Create SSL directory
    mkdir -p "$SSL_DIR"
    
    # Generate private key
    if openssl genrsa -out "$SSL_KEY" 2048 &>/dev/null; then
        echo "✓ SSL private key generated"
    else
        echo "✗ Failed to generate SSL private key"
        return 1
    fi
    
    # Generate certificate
    if openssl req -new -x509 -key "$SSL_KEY" -out "$SSL_CERT" -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" &>/dev/null; then
        echo "✓ SSL certificate generated"
    else
        echo "✗ Failed to generate SSL certificate"
        return 1
    fi
    
    # Set proper permissions
    chmod 600 "$SSL_KEY"
    chmod 644 "$SSL_CERT"
    
    echo "✓ SSL certificate generation completed"
    return 0
}

# Function to validate SSL certificate
validate_ssl_certificate() {
    echo "Validating SSL certificate..."
    
    if [[ ! -f "$SSL_CERT" ]] || [[ ! -f "$SSL_KEY" ]]; then
        echo "✗ SSL certificate files not found"
        return 1
    fi
    
    # Validate certificate
    if openssl x509 -in "$SSL_CERT" -text -noout &>/dev/null; then
        echo "✓ SSL certificate is valid"
    else
        echo "✗ SSL certificate is invalid"
        return 1
    fi
    
    # Validate private key
    if openssl rsa -in "$SSL_KEY" -check &>/dev/null; then
        echo "✓ SSL private key is valid"
    else
        echo "✗ SSL private key is invalid"
        return 1
    fi
    
    # Check certificate and key match
    local cert_hash=$(openssl x509 -noout -modulus -in "$SSL_CERT" | openssl md5)
    local key_hash=$(openssl rsa -noout -modulus -in "$SSL_KEY" | openssl md5)
    
    if [[ "$cert_hash" == "$key_hash" ]]; then
        echo "✓ SSL certificate and private key match"
    else
        echo "✗ SSL certificate and private key do not match"
        return 1
    fi
    
    echo "✓ SSL certificate validation completed"
    return 0
}

# Function to renew SSL certificate
renew_ssl_certificate() {
    echo "Renewing SSL certificate..."
    
    # Backup existing certificate
    if [[ -f "$SSL_CERT" ]]; then
        cp "$SSL_CERT" "$SSL_CERT.backup"
        echo "✓ Existing certificate backed up"
    fi
    
    # Generate new certificate
    if generate_ssl_certificate; then
        echo "✓ SSL certificate renewed successfully"
        return 0
    else
        echo "✗ Failed to renew SSL certificate"
        return 1
    fi
}

# Function to check SSL certificate expiry
check_ssl_expiry() {
    echo "Checking SSL certificate expiry..."
    
    if [[ ! -f "$SSL_CERT" ]]; then
        echo "✗ SSL certificate not found"
        return 1
    fi
    
    local expiry_date=$(openssl x509 -in "$SSL_CERT" -noout -enddate | cut -d= -f2)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp=$(date +%s)
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    echo "Certificate expires on: $expiry_date"
    echo "Days remaining: $days_remaining"
    
    if [[ $days_remaining -lt 30 ]]; then
        echo "⚠ Warning: Certificate expires in less than 30 days"
        return 1
    else
        echo "✓ Certificate is valid for more than 30 days"
        return 0
    fi
}

# Function to setup SSL for Xray
setup_ssl_for_xray() {
    echo "Setting up SSL for Xray..."
    
    # Generate SSL certificate if not exists
    if [[ ! -f "$SSL_CERT" ]] || [[ ! -f "$SSL_KEY" ]]; then
        if ! generate_ssl_certificate; then
            echo "Error: Failed to generate SSL certificate"
            return 1
        fi
    fi
    
    # Validate SSL certificate
    if ! validate_ssl_certificate; then
        echo "Error: SSL certificate validation failed"
        return 1
    fi
    
    # Check certificate expiry
    if ! check_ssl_expiry; then
        echo "Warning: SSL certificate is expiring soon"
    fi
    
    echo "✓ SSL setup for Xray completed"
    return 0
}

# Function to show SSL information
show_ssl_info() {
    echo "SSL Certificate Information"
    echo "=========================="
    
    if [[ -f "$SSL_CERT" ]]; then
        echo "Certificate file: $SSL_CERT"
        echo "Private key file: $SSL_KEY"
        echo ""
        
        # Show certificate details
        echo "Certificate details:"
        openssl x509 -in "$SSL_CERT" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
        echo ""
        
        # Check expiry
        check_ssl_expiry
    else
        echo "No SSL certificate found"
        echo "Run: $0 generate"
    fi
}

# Show usage
show_usage() {
    echo "SSL Manager Script"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  generate                 - Generate new SSL certificate"
    echo "  validate                 - Validate existing SSL certificate"
    echo "  renew                    - Renew SSL certificate"
    echo "  check                    - Check SSL certificate expiry"
    echo "  setup                    - Setup SSL for Xray"
    echo "  info                     - Show SSL certificate information"
    echo ""
    echo "Examples:"
    echo "  $0 generate"
    echo "  $0 validate"
    echo "  $0 setup"
    echo "  $0 info"
}

# Main function
main() {
    local command="$1"
    
    case "$command" in
        "generate")
            generate_ssl_certificate
            ;;
        "validate")
            validate_ssl_certificate
            ;;
        "renew")
            renew_ssl_certificate
            ;;
        "check")
            check_ssl_expiry
            ;;
        "setup")
            setup_ssl_for_xray
            ;;
        "info")
            show_ssl_info
            ;;
        *)
            echo "Error: Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check if openssl is installed
if ! command_exists openssl; then
    echo "Error: openssl is required but not installed"
    echo "Please install openssl: apt-get install openssl"
    exit 1
fi

# Run main function
main "$@"