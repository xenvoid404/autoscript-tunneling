#!/bin/bash

# Xray-core setup script for Modern Tunneling Autoscript
# Configures Xray-core with VMess, VLESS, and Trojan protocols

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/validator.sh"
source "$PROJECT_ROOT/config/system.conf"

# Initialize logging
init_logging

# Xray configuration files
XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_TEMPLATE="$PROJECT_ROOT/config/xray.json"

# Function to generate self-signed certificate
generate_ssl_certificate() {
    log_function_start "generate_ssl_certificate"
    
    print_section "Generating SSL Certificate"
    
    local cert_dir="/etc/xray"
    local cert_file="$cert_dir/xray.crt"
    local key_file="$cert_dir/xray.key"
    
    # Create certificate directory
    create_directory "$cert_dir" "755"
    
    # Get server IP address
    local server_ip
    server_ip=$(get_public_ip)
    
    if [[ -z "$server_ip" ]]; then
        print_warning "Could not get public IP, using localhost"
        server_ip="127.0.0.1"
    fi
    
    # Generate private key
    print_info "Generating private key..."
    if openssl genrsa -out "$key_file" 2048 &>/dev/null; then
        chmod 600 "$key_file"
        print_success "Private key generated"
        log_info "SSL private key generated"
    else
        print_error "Failed to generate private key"
        return 1
    fi
    
    # Generate certificate
    print_info "Generating certificate..."
    cat > /tmp/xray_cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = Modern Tunneling
OU = Autoscript
CN = ${server_ip}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ${server_ip}
IP.1 = ${server_ip}
IP.2 = 127.0.0.1
EOF
    
    if openssl req -new -x509 -key "$key_file" -out "$cert_file" -days 3650 \
        -config /tmp/xray_cert.conf -extensions v3_req &>/dev/null; then
        chmod 644 "$cert_file"
        rm -f /tmp/xray_cert.conf
        print_success "Certificate generated (valid for 10 years)"
        log_info "SSL certificate generated"
    else
        print_error "Failed to generate certificate"
        rm -f /tmp/xray_cert.conf
        return 1
    fi
    
    log_function_end "generate_ssl_certificate" 0
    return 0
}

# Function to configure Xray
configure_xray() {
    log_function_start "configure_xray"
    
    if [[ "$ENABLE_XRAY" != "true" ]]; then
        log_info "Xray configuration skipped (disabled in config)"
        return 0
    fi
    
    print_section "Configuring Xray-core"
    
    # Create necessary directories
    create_directory "$(dirname "$XRAY_CONFIG")" "755"
    create_directory "$XRAY_LOG_PATH" "755"
    
    # Backup existing configuration
    if [[ -f "$XRAY_CONFIG" ]]; then
        backup_file "$XRAY_CONFIG"
    fi
    
    # Copy template configuration
    if [[ -f "$XRAY_TEMPLATE" ]]; then
        cp "$XRAY_TEMPLATE" "$XRAY_CONFIG"
        print_success "Xray configuration template copied"
        log_info "Xray configuration template applied"
    else
        print_error "Xray template configuration not found"
        return 1
    fi
    
    # Generate SSL certificate
    if ! generate_ssl_certificate; then
        log_error "SSL certificate generation failed"
        return 1
    fi
    
    # Update configuration with system settings
    print_info "Updating Xray configuration..."
    
    # Update log level
    jq --arg level "$XRAY_LOG_LEVEL" '.log.loglevel = $level' "$XRAY_CONFIG" > /tmp/xray_config.tmp && \
    mv /tmp/xray_config.tmp "$XRAY_CONFIG"
    
    # Update ports
    jq --argjson port "$XRAY_VMESS_PORT" \
       '(.inbounds[] | select(.tag == "vmess-tcp") | .port) = $port' "$XRAY_CONFIG" > /tmp/xray_config.tmp && \
    mv /tmp/xray_config.tmp "$XRAY_CONFIG"
    
    jq --argjson port "$XRAY_VLESS_PORT" \
       '(.inbounds[] | select(.tag == "vless-tcp") | .port) = $port' "$XRAY_CONFIG" > /tmp/xray_config.tmp && \
    mv /tmp/xray_config.tmp "$XRAY_CONFIG"
    
    # Set proper permissions
    chmod 644 "$XRAY_CONFIG"
    
    # Validate configuration
    if xray -test -config "$XRAY_CONFIG" &>/dev/null; then
        print_success "Xray configuration is valid"
        log_info "Xray configuration validated successfully"
    else
        print_error "Xray configuration validation failed"
        log_error "Xray configuration validation failed"
        return 1
    fi
    
    log_function_end "configure_xray" 0
    return 0
}

# Function to create Xray systemd service
create_xray_service() {
    log_function_start "create_xray_service"
    
    print_section "Creating Xray Systemd Service"
    
    # Create systemd service file
    cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/local/bin/xray run -config $XRAY_CONFIG
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=$XRAY_LOG_PATH
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    
    # Create log rotation configuration
    cat > /etc/logrotate.d/xray << EOF
$XRAY_LOG_PATH/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 nobody nogroup
    copytruncate
    postrotate
        systemctl reload xray > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Xray systemd service created"
    log_info "Xray systemd service configuration completed"
    
    log_function_end "create_xray_service" 0
    return 0
}

# Function to setup Xray management scripts
setup_xray_management() {
    log_function_start "setup_xray_management"
    
    print_section "Setting Up Xray Management Scripts"
    
    # Create management scripts directory
    create_directory "/usr/local/bin/xray-mgmt" "755"
    
    # Create client management script
    cat > /usr/local/bin/xray-mgmt/client-manager.py << 'EOF'
#!/usr/bin/env python3
"""
Xray Client Management Script
Handles VMess, VLESS, and Trojan clients
"""

import json
import uuid
import base64
import qrcode
import argparse
import logging
from datetime import datetime, timedelta
from pathlib import Path
import urllib.parse

class XrayClientManager:
    def __init__(self, config_path="/usr/local/etc/xray/config.json"):
        self.config_path = Path(config_path)
        self.logger = logging.getLogger(__name__)
        
    def load_config(self):
        """Load Xray configuration"""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            self.logger.error(f"Failed to load config: {e}")
            return None
    
    def save_config(self, config):
        """Save Xray configuration"""
        try:
            with open(self.config_path, 'w') as f:
                json.dump(config, f, indent=2)
            return True
        except Exception as e:
            self.logger.error(f"Failed to save config: {e}")
            return False
    
    def add_vmess_client(self, username, uuid_str=None, alter_id=0):
        """Add VMess client"""
        config = self.load_config()
        if not config:
            return False
            
        client_uuid = uuid_str or str(uuid.uuid4())
        client = {
            "id": client_uuid,
            "alterId": alter_id,
            "email": username
        }
        
        # Add to VMess inbounds
        for inbound in config['inbounds']:
            if inbound.get('protocol') == 'vmess':
                inbound['settings']['clients'].append(client)
        
        if self.save_config(config):
            self.logger.info(f"VMess client added: {username}")
            return client_uuid
        return False
    
    def add_vless_client(self, username, uuid_str=None):
        """Add VLESS client"""
        config = self.load_config()
        if not config:
            return False
            
        client_uuid = uuid_str or str(uuid.uuid4())
        client = {
            "id": client_uuid,
            "email": username
        }
        
        # Add to VLESS inbounds
        for inbound in config['inbounds']:
            if inbound.get('protocol') == 'vless':
                inbound['settings']['clients'].append(client)
        
        if self.save_config(config):
            self.logger.info(f"VLESS client added: {username}")
            return client_uuid
        return False
    
    def add_trojan_client(self, username, password=None):
        """Add Trojan client"""
        config = self.load_config()
        if not config:
            return False
            
        client_password = password or str(uuid.uuid4())
        client = {
            "password": client_password,
            "email": username
        }
        
        # Add to Trojan inbounds
        for inbound in config['inbounds']:
            if inbound.get('protocol') == 'trojan':
                inbound['settings']['clients'].append(client)
        
        if self.save_config(config):
            self.logger.info(f"Trojan client added: {username}")
            return client_password
        return False
    
    def remove_client(self, username):
        """Remove client from all protocols"""
        config = self.load_config()
        if not config:
            return False
            
        removed = False
        for inbound in config['inbounds']:
            if 'clients' in inbound.get('settings', {}):
                original_count = len(inbound['settings']['clients'])
                inbound['settings']['clients'] = [
                    client for client in inbound['settings']['clients']
                    if client.get('email') != username
                ]
                if len(inbound['settings']['clients']) < original_count:
                    removed = True
        
        if removed and self.save_config(config):
            self.logger.info(f"Client removed: {username}")
            return True
        return False
    
    def list_clients(self):
        """List all clients"""
        config = self.load_config()
        if not config:
            return []
            
        clients = []
        for inbound in config['inbounds']:
            protocol = inbound.get('protocol')
            if 'clients' in inbound.get('settings', {}):
                for client in inbound['settings']['clients']:
                    clients.append({
                        'protocol': protocol,
                        'username': client.get('email', 'unknown'),
                        'id': client.get('id') or client.get('password'),
                        'tag': inbound.get('tag')
                    })
        return clients
    
    def generate_client_config(self, username, server_ip):
        """Generate client configuration"""
        config = self.load_config()
        if not config:
            return None
            
        configs = []
        for inbound in config['inbounds']:
            protocol = inbound.get('protocol')
            port = inbound.get('port')
            
            if 'clients' in inbound.get('settings', {}):
                for client in inbound['settings']['clients']:
                    if client.get('email') == username:
                        if protocol == 'vmess':
                            vmess_config = {
                                "v": "2",
                                "ps": f"{username}-vmess",
                                "add": server_ip,
                                "port": str(port),
                                "id": client['id'],
                                "aid": str(client.get('alterId', 0)),
                                "net": inbound['streamSettings']['network'],
                                "type": "none",
                                "host": "",
                                "path": inbound['streamSettings'].get('wsSettings', {}).get('path', ''),
                                "tls": "tls" if inbound['streamSettings'].get('security') == 'tls' else ""
                            }
                            vmess_url = "vmess://" + base64.b64encode(
                                json.dumps(vmess_config).encode()
                            ).decode()
                            configs.append({
                                'protocol': 'vmess',
                                'config': vmess_url,
                                'tag': inbound.get('tag')
                            })
                        
                        elif protocol == 'vless':
                            vless_params = {
                                'type': inbound['streamSettings']['network'],
                                'security': inbound['streamSettings'].get('security', 'none')
                            }
                            if 'wsSettings' in inbound['streamSettings']:
                                vless_params['path'] = inbound['streamSettings']['wsSettings'].get('path', '')
                            
                            vless_url = f"vless://{client['id']}@{server_ip}:{port}"
                            vless_url += "?" + urllib.parse.urlencode(vless_params)
                            vless_url += f"#{username}-vless"
                            
                            configs.append({
                                'protocol': 'vless',
                                'config': vless_url,
                                'tag': inbound.get('tag')
                            })
                        
                        elif protocol == 'trojan':
                            trojan_params = {
                                'type': inbound['streamSettings']['network'],
                                'security': inbound['streamSettings'].get('security', 'tls')
                            }
                            if 'wsSettings' in inbound['streamSettings']:
                                trojan_params['path'] = inbound['streamSettings']['wsSettings'].get('path', '')
                            
                            trojan_url = f"trojan://{client['password']}@{server_ip}:{port}"
                            trojan_url += "?" + urllib.parse.urlencode(trojan_params)
                            trojan_url += f"#{username}-trojan"
                            
                            configs.append({
                                'protocol': 'trojan',
                                'config': trojan_url,
                                'tag': inbound.get('tag')
                            })
        
        return configs

def main():
    parser = argparse.ArgumentParser(description='Xray Client Manager')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Add client commands
    add_parser = subparsers.add_parser('add', help='Add client')
    add_parser.add_argument('protocol', choices=['vmess', 'vless', 'trojan'])
    add_parser.add_argument('username', help='Client username')
    add_parser.add_argument('--uuid', help='Client UUID (for VMess/VLESS)')
    add_parser.add_argument('--password', help='Client password (for Trojan)')
    
    # Remove client command
    remove_parser = subparsers.add_parser('remove', help='Remove client')
    remove_parser.add_argument('username', help='Client username')
    
    # List clients command
    subparsers.add_parser('list', help='List all clients')
    
    # Generate config command
    config_parser = subparsers.add_parser('config', help='Generate client config')
    config_parser.add_argument('username', help='Client username')
    config_parser.add_argument('server_ip', help='Server IP address')
    
    args = parser.parse_args()
    
    logging.basicConfig(level=logging.INFO)
    manager = XrayClientManager()
    
    if args.command == 'add':
        if args.protocol == 'vmess':
            result = manager.add_vmess_client(args.username, args.uuid)
        elif args.protocol == 'vless':
            result = manager.add_vless_client(args.username, args.uuid)
        elif args.protocol == 'trojan':
            result = manager.add_trojan_client(args.username, args.password)
        
        if result:
            print(f"Client added successfully: {args.username}")
            print(f"ID/Password: {result}")
        else:
            print("Failed to add client")
    
    elif args.command == 'remove':
        if manager.remove_client(args.username):
            print(f"Client removed: {args.username}")
        else:
            print("Failed to remove client")
    
    elif args.command == 'list':
        clients = manager.list_clients()
        if clients:
            print("Active clients:")
            for client in clients:
                print(f"  {client['protocol']:<7} | {client['username']:<20} | {client['tag']}")
        else:
            print("No clients found")
    
    elif args.command == 'config':
        configs = manager.generate_client_config(args.username, args.server_ip)
        if configs:
            for config in configs:
                print(f"\n{config['protocol'].upper()} Configuration:")
                print(config['config'])
        else:
            print("No configurations found for this client")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x /usr/local/bin/xray-mgmt/client-manager.py
    
    # Create symbolic link for easy access
    ln -sf /usr/local/bin/xray-mgmt/client-manager.py /usr/local/bin/xray-client
    
    print_success "Xray management scripts created"
    log_info "Xray management scripts setup completed"
    
    log_function_end "setup_xray_management" 0
    return 0
}

# Function to enable and start Xray service
start_xray_service() {
    log_function_start "start_xray_service"
    
    print_section "Starting Xray Service"
    
    # Enable and start Xray service
    if enable_service "xray"; then
        print_success "Xray service started successfully"
        log_info "Xray service enabled and started"
    else
        print_error "Failed to start Xray service"
        return 1
    fi
    
    # Wait for service to be ready
    if wait_for_service "xray"; then
        print_success "Xray service is ready"
        log_info "Xray service is running and ready"
    else
        print_error "Xray service failed to start properly"
        return 1
    fi
    
    log_function_end "start_xray_service" 0
    return 0
}

# Function to verify Xray installation
verify_xray_installation() {
    log_function_start "verify_xray_installation"
    
    print_section "Verifying Xray Installation"
    
    local verification_failed=false
    
    # Check Xray binary
    if command_exists xray; then
        local xray_version=$(xray version | head -n1)
        print_success "✓ Xray binary: $xray_version"
        log_info "Xray binary verification passed"
    else
        print_error "✗ Xray binary not found"
        verification_failed=true
    fi
    
    # Check configuration file
    if [[ -f "$XRAY_CONFIG" ]]; then
        if xray -test -config "$XRAY_CONFIG" &>/dev/null; then
            print_success "✓ Configuration file is valid"
            log_info "Xray configuration verification passed"
        else
            print_error "✗ Configuration file is invalid"
            verification_failed=true
        fi
    else
        print_error "✗ Configuration file not found"
        verification_failed=true
    fi
    
    # Check SSL certificates
    if [[ -f "/etc/xray/xray.crt" && -f "/etc/xray/xray.key" ]]; then
        print_success "✓ SSL certificates are present"
        log_info "SSL certificates verification passed"
    else
        print_error "✗ SSL certificates not found"
        verification_failed=true
    fi
    
    # Check service status
    if systemctl is-active --quiet xray; then
        print_success "✓ Xray service is running"
        log_info "Xray service status verification passed"
    else
        print_error "✗ Xray service is not running"
        verification_failed=true
    fi
    
    # Check listening ports
    local ports=("$XRAY_VMESS_PORT" "$XRAY_VMESS_TLS_PORT" "$XRAY_VLESS_PORT" "$XRAY_VLESS_TLS_PORT" "$XRAY_TROJAN_PORT")
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            print_success "✓ Port $port is listening"
            log_debug "Port $port verification passed"
        else
            print_warning "⚠ Port $port is not listening"
            log_warn "Port $port verification failed"
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        print_error "Xray verification failed"
        log_function_end "verify_xray_installation" 1
        return 1
    else
        print_success "Xray verification completed successfully"
        log_function_end "verify_xray_installation" 0
        return 0
    fi
}

# Function to display Xray configuration summary
show_xray_summary() {
    print_section "Xray Configuration Summary"
    
    echo -e "${CYAN}Supported Protocols:${NC}"
    echo "✓ VMess (TCP): Port $XRAY_VMESS_PORT"
    echo "✓ VMess (WebSocket+TLS): Port $XRAY_VMESS_TLS_PORT"
    echo "✓ VLESS (TCP): Port $XRAY_VLESS_PORT"
    echo "✓ VLESS (WebSocket+TLS): Port $XRAY_VLESS_TLS_PORT"
    echo "✓ Trojan (TCP+TLS): Port $XRAY_TROJAN_PORT"
    echo "✓ Trojan (WebSocket+TLS): Port $XRAY_TROJAN_PORT"
    
    echo -e "\n${CYAN}Features:${NC}"
    echo "✓ TLS encryption enabled"
    echo "✓ WebSocket transport available"
    echo "✓ Traffic statistics enabled"
    echo "✓ Client management tools installed"
    
    echo -e "\n${CYAN}Management:${NC}"
    echo "✓ Client manager: /usr/local/bin/xray-client"
    echo "✓ Configuration: $XRAY_CONFIG"
    echo "✓ Logs: $XRAY_LOG_PATH"
    
    echo -e "\n${CYAN}Usage Examples:${NC}"
    echo "• Add VMess client: xray-client add vmess username"
    echo "• Add VLESS client: xray-client add vless username"
    echo "• Add Trojan client: xray-client add trojan username"
    echo "• List clients: xray-client list"
    echo "• Remove client: xray-client remove username"
    
    print_success "Xray setup completed successfully"
}

# Main Xray setup function
main() {
    log_function_start "main"
    
    # Check if running as root
    check_root
    
    print_banner
    print_section "Xray-core Setup"
    
    # Configure Xray
    if ! configure_xray; then
        log_error "Xray configuration failed"
        exit 1
    fi
    
    # Create systemd service
    if ! create_xray_service; then
        log_error "Xray service creation failed"
        exit 1
    fi
    
    # Setup management scripts
    if ! setup_xray_management; then
        log_error "Xray management setup failed"
    fi
    
    # Start Xray service
    if ! start_xray_service; then
        log_error "Xray service start failed"
        exit 1
    fi
    
    # Verify installation
    if ! verify_xray_installation; then
        log_error "Xray verification failed"
        exit 1
    fi
    
    # Show configuration summary
    show_xray_summary
    
    log_info "Xray-core setup completed successfully"
    log_function_end "main" 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi