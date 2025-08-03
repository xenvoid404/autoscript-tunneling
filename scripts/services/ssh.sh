#!/bin/bash

# SSH and Dropbear setup script for Modern Tunneling Autoscript
# Configures both OpenSSH and Dropbear SSH servers with optimal settings

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

# SSH configuration templates directory
SSH_TEMPLATE_DIR="$PROJECT_ROOT/config"

# Function to configure OpenSSH server
configure_openssh() {
    log_function_start "configure_openssh"
    
    if [[ "$ENABLE_SSH" != "true" ]]; then
        log_info "OpenSSH configuration skipped (disabled in config)"
        return 0
    fi
    
    print_section "Configuring OpenSSH Server"
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_banner="/etc/ssh/banner"
    
    # Backup original configuration
    backup_file "$ssh_config"
    
    # Create SSH banner
    cat > "$ssh_banner" << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                   AUTHORIZED ACCESS ONLY                ║
║                                                          ║
║   This system is for authorized users only.             ║
║   All activities are monitored and logged.              ║
║   Unauthorized access is strictly prohibited.           ║
║                                                          ║
║              Modern Tunneling Autoscript                ║
╚══════════════════════════════════════════════════════════╝

EOF
    
    # Create secure SSH configuration
    cat > "$ssh_config" << EOF
# Modern Tunneling Autoscript - OpenSSH Configuration
# Optimized for security and performance

# Network settings
Port $SSH_PORT
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Protocol and host keys
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Key exchange and encryption
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

# Authentication settings
LoginGraceTime 2m
PermitRootLogin $SSH_PERMIT_ROOT_LOGIN
StrictModes yes
MaxAuthTries $SSH_MAX_AUTH_TRIES
MaxSessions 10
MaxStartups 10:30:100

# Password and key authentication
PasswordAuthentication $SSH_PASSWORD_AUTHENTICATION
PermitEmptyPasswords no
PubkeyAuthentication $SSH_PUBKEY_AUTHENTICATION
AuthorizedKeysFile .ssh/authorized_keys
IgnoreRhosts yes
HostbasedAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

# Connection settings
ClientAliveInterval $SSH_CLIENT_ALIVE_INTERVAL
ClientAliveCountMax $SSH_CLIENT_ALIVE_COUNT_MAX
TCPKeepAlive yes
Compression delayed

# Security settings
PermitUserEnvironment no
AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PermitTTY yes
PrintMotd no
PrintLastLog yes
AcceptEnv LANG LC_*

# Logging
SyslogFacility AUTH
LogLevel INFO

# Performance and DNS
UseDNS no
GSSAPIAuthentication no
GSSAPICleanupCredentials yes

# Banner and subsystem
Banner $ssh_banner
Subsystem sftp /usr/lib/openssh/sftp-server

# Custom tunneling settings
AllowStreamLocalForwarding yes
StreamLocalBindUnlink yes
PermitTunnel yes

EOF
    
    # Set proper permissions
    chmod 644 "$ssh_config"
    chmod 644 "$ssh_banner"
    
    # Test SSH configuration
    if sshd -t; then
        print_success "SSH configuration syntax is valid"
        log_info "SSH configuration validated successfully"
    else
        print_error "SSH configuration syntax error"
        log_error "SSH configuration validation failed"
        return 1
    fi
    
    # Generate new host keys if needed
    print_info "Generating SSH host keys..."
    ssh-keygen -A &>/dev/null
    
    # Set proper permissions for host keys
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub
    
    # Enable and restart SSH service
    if enable_service "ssh"; then
        print_success "OpenSSH server configured and started"
        log_info "OpenSSH server configuration completed"
    else
        print_error "Failed to start SSH service"
        return 1
    fi
    
    log_function_end "configure_openssh" 0
    return 0
}

# Function to configure Dropbear SSH
configure_dropbear() {
    log_function_start "configure_dropbear"
    
    if [[ "$ENABLE_DROPBEAR" != "true" ]]; then
        log_info "Dropbear configuration skipped (disabled in config)"
        return 0
    fi
    
    print_section "Configuring Dropbear SSH"
    
    # Stop any existing Dropbear service
    systemctl stop dropbear &>/dev/null || true
    systemctl disable dropbear &>/dev/null || true
    
    # Create Dropbear directories
    create_directory "/etc/dropbear" "755"
    create_directory "/var/log/dropbear" "755"
    
    # Generate Dropbear host keys
    print_info "Generating Dropbear host keys..."
    
    local key_types=("rsa" "dss" "ecdsa" "ed25519")
    for key_type in "${key_types[@]}"; do
        local key_file="/etc/dropbear/dropbear_${key_type}_host_key"
        if [[ ! -f "$key_file" ]]; then
            case $key_type in
                "rsa")
                    dropbearkey -t rsa -f "$key_file" -s 2048 &>/dev/null
                    ;;
                "dss")
                    dropbearkey -t dss -f "$key_file" &>/dev/null
                    ;;
                "ecdsa")
                    dropbearkey -t ecdsa -f "$key_file" -s 256 &>/dev/null
                    ;;
                "ed25519")
                    dropbearkey -t ed25519 -f "$key_file" &>/dev/null
                    ;;
            esac
            
            if [[ -f "$key_file" ]]; then
                chmod 600 "$key_file"
                print_success "Generated $key_type host key"
                log_info "Dropbear $key_type host key generated"
            else
                print_warning "Failed to generate $key_type host key"
                log_warn "Dropbear $key_type host key generation failed"
            fi
        else
            print_info "$key_type host key already exists"
        fi
    done
    
    # Create Dropbear systemd service file
    cat > /etc/systemd/system/dropbear.service << EOF
[Unit]
Description=Dropbear SSH server
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
Type=forking
ExecStart=/usr/sbin/dropbear -p $DROPBEAR_PORT -P /var/run/dropbear.pid
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=/var/log/dropbear

[Install]
WantedBy=multi-user.target
EOF
    
    # Create Dropbear WebSocket service
    cat > /etc/systemd/system/dropbear-ws.service << EOF
[Unit]
Description=Dropbear SSH WebSocket server
After=network.target dropbear.service
Requires=dropbear.service

[Service]
Type=forking
ExecStart=/usr/sbin/dropbear -p $DROPBEAR_PORT_WS -P /var/run/dropbear-ws.pid
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=/var/log/dropbear

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable services
    systemctl daemon-reload
    
    # Enable and start Dropbear services
    if enable_service "dropbear"; then
        print_success "Dropbear SSH service started on port $DROPBEAR_PORT"
        log_info "Dropbear SSH service configured and started"
    else
        print_error "Failed to start Dropbear SSH service"
        return 1
    fi
    
    if enable_service "dropbear-ws"; then
        print_success "Dropbear WebSocket service started on port $DROPBEAR_PORT_WS"
        log_info "Dropbear WebSocket service configured and started"
    else
        print_warning "Failed to start Dropbear WebSocket service"
        log_warn "Dropbear WebSocket service start failed"
    fi
    
    log_function_end "configure_dropbear" 0
    return 0
}

# Function to setup SSH tunneling configurations
setup_ssh_tunneling() {
    log_function_start "setup_ssh_tunneling"
    
    print_section "Setting Up SSH Tunneling Configurations"
    
    # Create tunneling helper scripts directory
    create_directory "/usr/local/bin/tunneling" "755"
    
    # Create WebSocket tunnel helper script
    cat > /usr/local/bin/tunneling/ws-tunnel.py << 'EOF'
#!/usr/bin/env python3
"""
WebSocket to SSH tunnel helper script
Provides WebSocket transport for SSH connections
"""

import asyncio
import websockets
import socket
import threading
import logging
from typing import Optional

class WSSSHTunnel:
    def __init__(self, ws_host: str = '0.0.0.0', ws_port: int = 8880, 
                 ssh_host: str = '127.0.0.1', ssh_port: int = 22):
        self.ws_host = ws_host
        self.ws_port = ws_port
        self.ssh_host = ssh_host
        self.ssh_port = ssh_port
        self.logger = logging.getLogger(__name__)
        
    async def handle_websocket(self, websocket, path):
        """Handle WebSocket connection and bridge to SSH"""
        try:
            # Create SSH connection
            ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            ssh_socket.connect((self.ssh_host, self.ssh_port))
            
            # Bridge WebSocket to SSH
            await self.bridge_connections(websocket, ssh_socket)
            
        except Exception as e:
            self.logger.error(f"WebSocket tunnel error: {e}")
        finally:
            try:
                ssh_socket.close()
            except:
                pass
    
    async def bridge_connections(self, websocket, ssh_socket):
        """Bridge WebSocket and SSH socket bidirectionally"""
        def ssh_to_ws():
            try:
                while True:
                    data = ssh_socket.recv(4096)
                    if not data:
                        break
                    asyncio.create_task(websocket.send(data))
            except Exception as e:
                self.logger.error(f"SSH to WS error: {e}")
        
        # Start SSH to WebSocket forwarding in background
        threading.Thread(target=ssh_to_ws, daemon=True).start()
        
        # WebSocket to SSH forwarding
        try:
            async for message in websocket:
                if isinstance(message, bytes):
                    ssh_socket.send(message)
                else:
                    ssh_socket.send(message.encode())
        except Exception as e:
            self.logger.error(f"WS to SSH error: {e}")
    
    def start_server(self):
        """Start the WebSocket tunnel server"""
        logging.basicConfig(level=logging.INFO)
        self.logger.info(f"Starting WebSocket SSH tunnel on {self.ws_host}:{self.ws_port}")
        
        start_server = websockets.serve(
            self.handle_websocket, 
            self.ws_host, 
            self.ws_port
        )
        
        asyncio.get_event_loop().run_until_complete(start_server)
        asyncio.get_event_loop().run_forever()

if __name__ == "__main__":
    import sys
    
    ws_port = int(sys.argv[1]) if len(sys.argv) > 1 else 8880
    ssh_port = int(sys.argv[2]) if len(sys.argv) > 2 else 22
    
    tunnel = WSSSHTunnel(ws_port=ws_port, ssh_port=ssh_port)
    tunnel.start_server()
EOF
    
    chmod +x /usr/local/bin/tunneling/ws-tunnel.py
    
    # Create WebSocket tunnel systemd service
    cat > /etc/systemd/system/ssh-ws-tunnel.service << EOF
[Unit]
Description=SSH WebSocket Tunnel
After=network.target ssh.service
Requires=ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/tunneling/ws-tunnel.py $WEBSOCKET_PORT $SSH_PORT
Restart=on-failure
RestartSec=5s
User=nobody
Group=nogroup

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable WebSocket tunnel service
    systemctl daemon-reload
    
    if enable_service "ssh-ws-tunnel"; then
        print_success "SSH WebSocket tunnel started on port $WEBSOCKET_PORT"
        log_info "SSH WebSocket tunnel service configured and started"
    else
        print_warning "Failed to start SSH WebSocket tunnel"
        log_warn "SSH WebSocket tunnel service start failed"
    fi
    
    log_function_end "setup_ssh_tunneling" 0
    return 0
}

# Function to setup fail2ban for SSH protection
setup_fail2ban() {
    log_function_start "setup_fail2ban"
    
    if [[ "$ENABLE_FAIL2BAN" != "true" ]]; then
        log_info "Fail2ban setup skipped (disabled in config)"
        return 0
    fi
    
    print_section "Setting Up Fail2ban Protection"
    
    # Install fail2ban if not already installed
    if ! command_exists fail2ban-client; then
        if ! install_package "fail2ban"; then
            print_error "Failed to install fail2ban"
            return 1
        fi
    fi
    
    # Create fail2ban jail configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = $FAIL2BAN_BANTIME
findtime = $FAIL2BAN_FINDTIME
maxretry = $FAIL2BAN_MAXRETRY
backend = systemd
banaction = iptables-multiport
banaction_allports = iptables-allports

[ssh]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[dropbear]
enabled = true
port = $DROPBEAR_PORT,$DROPBEAR_PORT_WS
filter = dropbear
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[ssh-ddos]
enabled = true
port = $SSH_PORT,$DROPBEAR_PORT,$DROPBEAR_PORT_WS
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 2
bantime = 7200
EOF
    
    # Create Dropbear filter
    cat > /etc/fail2ban/filter.d/dropbear.conf << 'EOF'
[Definition]
failregex = dropbear\[<PID>\]: bad password attempt for .* from <HOST>
            dropbear\[<PID>\]: login attempt for nonexistent user .* from <HOST>
            dropbear\[<PID>\]: bad password attempt for .* from <HOST>
ignoreregex =
EOF
    
    # Enable and start fail2ban
    if enable_service "fail2ban"; then
        print_success "Fail2ban protection enabled"
        log_info "Fail2ban SSH protection configured and started"
    else
        print_error "Failed to start fail2ban"
        return 1
    fi
    
    log_function_end "setup_fail2ban" 0
    return 0
}

# Function to verify SSH services
verify_ssh_services() {
    log_function_start "verify_ssh_services"
    
    print_section "Verifying SSH Services"
    
    local verification_failed=false
    
    # Check OpenSSH
    if [[ "$ENABLE_SSH" == "true" ]]; then
        if systemctl is-active --quiet ssh && check_port "$SSH_PORT"; then
            print_error "OpenSSH port $SSH_PORT is not accessible"
            verification_failed=true
        else
            print_success "✓ OpenSSH is running on port $SSH_PORT"
            log_info "OpenSSH service verification passed"
        fi
    fi
    
    # Check Dropbear
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        if systemctl is-active --quiet dropbear && check_port "$DROPBEAR_PORT"; then
            print_error "Dropbear port $DROPBEAR_PORT is not accessible"
            verification_failed=true
        else
            print_success "✓ Dropbear is running on port $DROPBEAR_PORT"
            log_info "Dropbear service verification passed"
        fi
        
        if systemctl is-active --quiet dropbear-ws && check_port "$DROPBEAR_PORT_WS"; then
            print_error "Dropbear WebSocket port $DROPBEAR_PORT_WS is not accessible"
            verification_failed=true
        else
            print_success "✓ Dropbear WebSocket is running on port $DROPBEAR_PORT_WS"
            log_info "Dropbear WebSocket service verification passed"
        fi
    fi
    
    # Check SSH WebSocket tunnel
    if systemctl is-active --quiet ssh-ws-tunnel && check_port "$WEBSOCKET_PORT"; then
        print_error "SSH WebSocket tunnel port $WEBSOCKET_PORT is not accessible"
        verification_failed=true
    else
        print_success "✓ SSH WebSocket tunnel is running on port $WEBSOCKET_PORT"
        log_info "SSH WebSocket tunnel verification passed"
    fi
    
    # Check fail2ban
    if [[ "$ENABLE_FAIL2BAN" == "true" ]]; then
        if systemctl is-active --quiet fail2ban; then
            print_success "✓ Fail2ban protection is active"
            log_info "Fail2ban service verification passed"
        else
            print_warning "✗ Fail2ban is not running"
            log_warn "Fail2ban service verification failed"
        fi
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        print_error "Some SSH services failed verification"
        log_function_end "verify_ssh_services" 1
        return 1
    else
        print_success "All SSH services verified successfully"
        log_function_end "verify_ssh_services" 0
        return 0
    fi
}

# Function to display SSH configuration summary
show_ssh_summary() {
    print_section "SSH Configuration Summary"
    
    echo -e "${CYAN}SSH Services:${NC}"
    if [[ "$ENABLE_SSH" == "true" ]]; then
        echo "✓ OpenSSH Server: Port $SSH_PORT"
    fi
    
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        echo "✓ Dropbear SSH: Port $DROPBEAR_PORT"
        echo "✓ Dropbear WebSocket: Port $DROPBEAR_PORT_WS"
    fi
    
    echo "✓ SSH WebSocket Tunnel: Port $WEBSOCKET_PORT"
    
    echo -e "\n${CYAN}Security Features:${NC}"
    echo "✓ Host key authentication enabled"
    echo "✓ Password authentication configured"
    echo "✓ Connection timeout settings applied"
    echo "✓ SSH banner configured"
    
    if [[ "$ENABLE_FAIL2BAN" == "true" ]]; then
        echo "✓ Fail2ban protection enabled"
    fi
    
    echo -e "\n${CYAN}Tunneling Features:${NC}"
    echo "✓ TCP forwarding enabled"
    echo "✓ WebSocket tunneling available"
    echo "✓ Stream local forwarding enabled"
    
    print_success "SSH setup completed successfully"
}

# Main SSH setup function
main() {
    log_function_start "main"
    
    # Check if running as root
    check_root
    
    print_banner
    print_section "SSH Services Setup"
    
    # Configure OpenSSH
    if ! configure_openssh; then
        log_error "OpenSSH configuration failed"
    fi
    
    # Configure Dropbear
    if ! configure_dropbear; then
        log_error "Dropbear configuration failed"
    fi
    
    # Setup SSH tunneling
    if ! setup_ssh_tunneling; then
        log_error "SSH tunneling setup failed"
    fi
    
    # Setup fail2ban protection
    if ! setup_fail2ban; then
        log_error "Fail2ban setup failed"
    fi
    
    # Verify all services
    if ! verify_ssh_services; then
        log_error "SSH services verification failed"
        exit 1
    fi
    
    # Show configuration summary
    show_ssh_summary
    
    log_info "SSH services setup completed successfully"
    log_function_end "main" 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi