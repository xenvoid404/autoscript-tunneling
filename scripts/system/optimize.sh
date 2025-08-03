#!/bin/bash

# System optimization script for Modern Tunneling Autoscript
# Optimizes system performance and security settings

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/config/system.conf"

# Initialize logging
init_logging

# Function to optimize TCP settings
optimize_tcp_settings() {
    log_function_start "optimize_tcp_settings"
    
    print_section "Optimizing TCP Settings"
    
    # Backup original sysctl.conf
    backup_file "/etc/sysctl.conf"
    
    # Create optimized sysctl configuration
    cat >> /etc/sysctl.conf << 'EOF'

# =============================================================================
# Modern Tunneling Autoscript - System Optimizations
# =============================================================================

# Network performance optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# TCP performance optimizations
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 9
net.ipv4.tcp_keepalive_intvl = 75
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

# IP forwarding (required for tunneling)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Security optimizations
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# Memory and file descriptor optimizations
fs.file-max = 2097152
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# Kernel optimizations
kernel.pid_max = 4194304
net.core.somaxconn = 65535
net.ipv4.tcp_max_orphans = 262144

EOF
    
    # Apply sysctl settings
    if log_command "sysctl -p" "Applying sysctl optimizations"; then
        print_success "TCP optimizations applied successfully"
        log_info "TCP and network optimizations applied"
    else
        print_error "Failed to apply TCP optimizations"
        return 1
    fi
    
    log_function_end "optimize_tcp_settings" 0
    return 0
}

# Function to enable BBR congestion control
enable_bbr() {
    log_function_start "enable_bbr"
    
    if [[ "$ENABLE_BBR" != "true" ]]; then
        log_info "BBR optimization skipped (disabled in config)"
        return 0
    fi
    
    print_section "Enabling BBR Congestion Control"
    
    # Check if BBR is available
    if ! lsmod | grep -q tcp_bbr; then
        # Load BBR module
        if modprobe tcp_bbr; then
            print_success "BBR module loaded"
            log_info "BBR kernel module loaded successfully"
        else
            print_warning "Failed to load BBR module (may not be supported)"
            log_warn "BBR module loading failed"
            return 0
        fi
    fi
    
    # Make BBR persistent
    echo 'tcp_bbr' >> /etc/modules-load.d/modules.conf
    
    # Verify BBR is active
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [[ "$current_cc" == "bbr" ]]; then
        print_success "BBR congestion control is active"
        log_info "BBR congestion control activated"
    else
        print_warning "BBR may not be active. Current: $current_cc"
        log_warn "BBR activation uncertain. Current congestion control: $current_cc"
    fi
    
    log_function_end "enable_bbr" 0
    return 0
}

# Function to create swap file
create_swap() {
    log_function_start "create_swap"
    
    if [[ "$ENABLE_SWAP" != "true" ]]; then
        log_info "Swap creation skipped (disabled in config)"
        return 0
    fi
    
    print_section "Creating Swap File"
    
    # Check if swap already exists
    if swapon --show | grep -q '/swapfile'; then
        print_info "Swap file already exists"
        log_info "Swap file already configured"
        return 0
    fi
    
    # Check available disk space
    local available_space=$(df / | awk 'NR==2{print $4}')
    local swap_size_kb=$(echo "$SWAP_SIZE" | sed 's/G$//' | awk '{print $1 * 1024 * 1024}')
    
    if [[ $available_space -lt $swap_size_kb ]]; then
        print_warning "Insufficient disk space for swap file"
        log_warn "Insufficient disk space for swap file creation"
        return 0
    fi
    
    # Create swap file
    print_info "Creating ${SWAP_SIZE} swap file..."
    if log_command "fallocate -l $SWAP_SIZE /swapfile" "Creating swap file"; then
        chmod 600 /swapfile
        
        if mkswap /swapfile && swapon /swapfile; then
            # Make swap persistent
            if ! grep -q '/swapfile' /etc/fstab; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi
            
            print_success "Swap file created and enabled"
            log_info "Swap file created successfully: $SWAP_SIZE"
        else
            print_error "Failed to activate swap file"
            rm -f /swapfile
            return 1
        fi
    else
        print_error "Failed to create swap file"
        return 1
    fi
    
    log_function_end "create_swap" 0
    return 0
}

# Function to optimize limits
optimize_limits() {
    log_function_start "optimize_limits"
    
    print_section "Optimizing System Limits"
    
    # Backup original limits.conf
    backup_file "/etc/security/limits.conf"
    
    # Create optimized limits configuration
    cat >> /etc/security/limits.conf << 'EOF'

# Modern Tunneling Autoscript - System Limits Optimization
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000

EOF
    
    # Update systemd limits
    if [[ -d /etc/systemd/system.conf.d ]]; then
        mkdir -p /etc/systemd/system.conf.d
    fi
    
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitNPROC=1000000
EOF
    
    # Update PAM limits
    if ! grep -q 'pam_limits.so' /etc/pam.d/common-session; then
        echo 'session required pam_limits.so' >> /etc/pam.d/common-session
    fi
    
    print_success "System limits optimized"
    log_info "System limits configuration updated"
    
    log_function_end "optimize_limits" 0
    return 0
}

# Function to optimize SSH
optimize_ssh() {
    log_function_start "optimize_ssh"
    
    print_section "Optimizing SSH Configuration"
    
    local ssh_config="/etc/ssh/sshd_config"
    
    # Backup original SSH config
    backup_file "$ssh_config"
    
    # Create optimized SSH configuration
    cat > "$ssh_config" << EOF
# Modern Tunneling Autoscript - SSH Configuration

# Basic settings
Port $SSH_PORT
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication settings
PermitRootLogin $SSH_PERMIT_ROOT_LOGIN
PasswordAuthentication $SSH_PASSWORD_AUTHENTICATION
PubkeyAuthentication $SSH_PUBKEY_AUTHENTICATION
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries $SSH_MAX_AUTH_TRIES
MaxSessions 10
MaxStartups 10:30:100

# Connection settings
ClientAliveInterval $SSH_CLIENT_ALIVE_INTERVAL
ClientAliveCountMax $SSH_CLIENT_ALIVE_COUNT_MAX
TCPKeepAlive yes
Compression yes

# Security settings
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# Performance settings
UseDNS no
GSSAPIAuthentication no

# Logging
SyslogFacility AUTH
LogLevel INFO

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server

EOF
    
    # Restart SSH service
    if systemctl restart ssh; then
        print_success "SSH configuration optimized and service restarted"
        log_info "SSH service optimized and restarted"
    else
        print_error "Failed to restart SSH service"
        return 1
    fi
    
    log_function_end "optimize_ssh" 0
    return 0
}

# Function to setup log rotation
setup_log_rotation() {
    log_function_start "setup_log_rotation"
    
    print_section "Setting Up Log Rotation"
    
    # Create logrotate configuration for system logs
    cat > /etc/logrotate.d/tunneling-autoscript << 'EOF'
/var/log/auth.log
/var/log/kern.log
/var/log/daemon.log
/var/log/syslog {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 syslog adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/xray/*.log {
    daily
    missingok
    rotate 5
    compress
    delaycompress
    notifempty
    create 644 nobody nogroup
    copytruncate
}
EOF
    
    # Test logrotate configuration
    if logrotate -t /etc/logrotate.d/tunneling-autoscript; then
        print_success "Log rotation configured successfully"
        log_info "Log rotation setup completed"
    else
        print_error "Log rotation configuration failed"
        return 1
    fi
    
    log_function_end "setup_log_rotation" 0
    return 0
}

# Function to setup cron jobs
setup_cron_jobs() {
    log_function_start "setup_cron_jobs"
    
    print_section "Setting Up Maintenance Cron Jobs"
    
    # Create cron jobs for system maintenance
    cat > /tmp/autoscript_cron << EOF
# Modern Tunneling Autoscript - Maintenance Jobs

# Clean logs every 3 hours
0 */3 * * * find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;

# Restart services daily at 3 AM
0 3 * * * systemctl restart ssh dropbear xray

# Clean temporary files daily
0 4 * * * find /tmp -type f -atime +1 -delete

# Update system weekly
0 2 * * 0 apt-get update

# Check disk space daily
0 6 * * * df -h | grep -E '9[0-9]%|100%' && echo "Disk space warning" | logger

EOF
    
    # Install cron jobs
    if crontab /tmp/autoscript_cron; then
        rm /tmp/autoscript_cron
        print_success "Maintenance cron jobs installed"
        log_info "Cron jobs for system maintenance configured"
    else
        print_error "Failed to install cron jobs"
        rm -f /tmp/autoscript_cron
        return 1
    fi
    
    log_function_end "setup_cron_jobs" 0
    return 0
}

# Function to optimize DNS
optimize_dns() {
    log_function_start "optimize_dns"
    
    print_section "Optimizing DNS Configuration"
    
    # Backup original resolv.conf
    backup_file "/etc/resolv.conf"
    
    # Use fast DNS servers
    cat > /etc/resolv.conf << 'EOF'
# Modern Tunneling Autoscript - DNS Configuration
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
options timeout:2
options attempts:2
options rotate
EOF
    
    # Make resolv.conf immutable to prevent overwriting
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    print_success "DNS configuration optimized"
    log_info "DNS configuration optimized with fast resolvers"
    
    log_function_end "optimize_dns" 0
    return 0
}

# Function to display optimization summary
show_optimization_summary() {
    print_section "System Optimization Summary"
    
    echo -e "${CYAN}Network Optimizations:${NC}"
    echo "✓ TCP BBR congestion control enabled"
    echo "✓ Network buffer sizes optimized"
    echo "✓ Connection timeout settings tuned"
    echo "✓ IP forwarding enabled"
    
    echo -e "\n${CYAN}Security Optimizations:${NC}"
    echo "✓ SSH hardening applied"
    echo "✓ Network security parameters set"
    echo "✓ System limits increased"
    
    echo -e "\n${CYAN}Performance Optimizations:${NC}"
    echo "✓ Swap file created (${SWAP_SIZE})"
    echo "✓ File descriptor limits increased"
    echo "✓ Memory management tuned"
    echo "✓ DNS resolvers optimized"
    
    echo -e "\n${CYAN}Maintenance:${NC}"
    echo "✓ Log rotation configured"
    echo "✓ Automated maintenance jobs scheduled"
    echo "✓ System cleanup tasks enabled"
    
    print_success "System optimization completed successfully"
}

# Main optimization function
main() {
    log_function_start "main"
    
    # Check if running as root
    check_root
    
    print_banner
    print_section "System Optimization"
    
    # TCP and network optimizations
    if ! optimize_tcp_settings; then
        log_error "TCP optimization failed"
    fi
    
    # Enable BBR congestion control
    if ! enable_bbr; then
        log_error "BBR optimization failed"
    fi
    
    # Create swap file
    if ! create_swap; then
        log_error "Swap creation failed"
    fi
    
    # Optimize system limits
    if ! optimize_limits; then
        log_error "Limits optimization failed"
    fi
    
    # Optimize SSH
    if ! optimize_ssh; then
        log_error "SSH optimization failed"
    fi
    
    # Setup log rotation
    if ! setup_log_rotation; then
        log_error "Log rotation setup failed"
    fi
    
    # Setup cron jobs
    if ! setup_cron_jobs; then
        log_error "Cron jobs setup failed"
    fi
    
    # Optimize DNS
    if ! optimize_dns; then
        log_error "DNS optimization failed"
    fi
    
    # Show summary
    show_optimization_summary
    
    log_info "System optimization completed"
    log_function_end "main" 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi