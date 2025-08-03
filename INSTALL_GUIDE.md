# Modern Tunneling Autoscript - Installation Guide

## Overview

Modern Tunneling Autoscript adalah solusi tunneling yang production-ready, dirancang khusus untuk mengubah kuota game/edukasi menjadi kuota reguler menggunakan berbagai protokol tunneling modern.

## System Requirements

### Operating System

-   **Debian 11+** (Bullseye atau newer)
-   **Ubuntu 22.04+** (Jammy Jellyfish atau newer)

### Hardware Requirements

-   **RAM**: Minimal 512MB (1GB recommended)
-   **Storage**: Minimal 2GB free space
-   **CPU**: 1 core (2 cores recommended)
-   **Network**: Public IP address

### Prerequisites

-   Root access ke server
-   Koneksi internet yang stabil
-   Basic knowledge of Linux commands

## Supported Protocols

### SSH Tunneling

-   **OpenSSH Server** - Port 22 (default)
-   **Dropbear SSH** - Port 109
-   **Dropbear WebSocket** - Port 143
-   **SSH WebSocket Tunnel** - Port 8880

### Xray-core Protocols

-   **VMess TCP** - Port 80
-   **VMess WebSocket+TLS** - Port 443
-   **VLESS TCP** - Port 80
-   **VLESS WebSocket+TLS** - Port 443
-   **Trojan TCP+TLS** - Port 443
-   **Trojan WebSocket+TLS** - Port 443

## Installation Methods

### Method 1: Quick Install (Recommended)

```bash
# Download and run installer
wget -O install.sh https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Method 2: Clone Repository

```bash
# Clone repository
git clone https://github.com/your-repo/modern-tunneling-autoscript.git
cd modern-tunneling-autoscript

# Run installer
sudo ./install.sh
```

## Installation Process

### Step 1: System Compatibility Check

Script akan mengecek:

-   OS compatibility (Debian 11+ or Ubuntu 22.04+)
-   Root privileges
-   Internet connectivity

### Step 2: Dependencies Installation

-   Basic system packages (curl, wget, jq, etc.)
-   Development tools
-   Xray-core binary
-   Dropbear SSH server

### Step 3: System Optimization

-   TCP BBR congestion control
-   Network buffer optimization
-   System limits increase
-   Swap file creation
-   DNS optimization

### Step 4: Service Configuration

-   SSH server hardening
-   Dropbear SSH setup
-   Xray-core configuration
-   WebSocket tunneling setup

### Step 5: Security Setup

-   UFW firewall configuration
-   Fail2ban protection
-   SSL certificate generation
-   Rate limiting rules

### Step 6: Management Tools

-   Account management system
-   Web-based control panel
-   Command-line utilities
-   Automated maintenance tasks

## Post-Installation

### Access Management Panel

```bash
# Launch main menu
autoscript
```

### Quick Commands

```bash
# SSH account management
ssh-account add username          # Add SSH account
ssh-account list                  # List all accounts
ssh-account delete username       # Delete account

# Xray client management
xray-client add vmess username    # Add VMess client
xray-client add vless username    # Add VLESS client
xray-client add trojan username   # Add Trojan client
xray-client list                  # List all clients
xray-client config username IP    # Generate client config
```

## Configuration Files

### Main Configuration

-   `/opt/autoscript/config/system.conf` - System configuration
-   `/usr/local/etc/xray/config.json` - Xray configuration
-   `/etc/ssh/sshd_config` - SSH configuration

### Account Databases

-   `/etc/autoscript/accounts/ssh_accounts.txt` - SSH accounts
-   Xray clients stored in `/usr/local/etc/xray/config.json`

### Log Files

-   `/var/log/autoscript/autoscript.log` - Main log
-   `/var/log/autoscript/error.log` - Error log
-   `/var/log/autoscript/access.log` - Access log
-   `/var/log/xray/` - Xray logs

## Firewall Configuration

### Allowed Ports

-   **22** - SSH
-   **80** - HTTP, VMess, VLESS
-   **109** - Dropbear SSH
-   **143** - Dropbear WebSocket
-   **443** - HTTPS, TLS protocols
-   **8880** - SSH WebSocket

### Security Features

-   Rate limiting on SSH ports
-   Fail2ban protection
-   Automatic IP blocking
-   DDoS protection

## Account Management

### SSH Accounts

```bash
# Create account with 30 days validity
ssh-account add testuser

# Create account with custom validity
ssh-account add testuser2 "" 60

# Extend account validity
ssh-account extend testuser 30

# Change password
ssh-account password testuser

# Show account details
ssh-account show testuser

# Cleanup expired accounts
ssh-account cleanup
```

### Xray Clients

```bash
# Add VMess client
xray-client add vmess testuser

# Add VLESS client
xray-client add vless testuser

# Add Trojan client
xray-client add trojan testuser

# Generate configuration
xray-client config testuser YOUR_SERVER_IP

# Remove client
xray-client remove testuser
```

## Troubleshooting

### Common Issues

#### Installation Fails

```bash
# Check system compatibility
cat /etc/os-release

# Check internet connectivity
ping -c 4 8.8.8.8

# Check available space
df -h

# Run with debug
bash -x install.sh
```

#### Services Not Starting

```bash
# Check service status
systemctl status ssh
systemctl status dropbear
systemctl status xray

# Check logs
journalctl -u ssh -f
journalctl -u xray -f

# Restart services
systemctl restart ssh dropbear xray
```

#### Firewall Issues

```bash
# Check UFW status
ufw status verbose

# Reset firewall (CAUTION!)
ufw --force reset
# Re-run installer to reconfigure
```

#### Connection Problems

```bash
# Test SSH connection
ssh username@your_server_ip -p 22

# Check port availability
netstat -tuln | grep :22

# Verify firewall rules
ufw status numbered
```

### Log Analysis

```bash
# Main logs
tail -f /var/log/autoscript/autoscript.log

# Error logs
tail -f /var/log/autoscript/error.log

# Xray logs
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# System logs
journalctl -f
```

## Client Configuration Examples

### SSH Client (HTTP Injector/Custom)

```
Server: YOUR_SERVER_IP
Port: 22 (SSH) or 109 (Dropbear)
Username: your_username
Password: your_password

WebSocket Settings:
Host: YOUR_SERVER_IP
Port: 8880
Path: /ws
```

### VMess Client

```json
{
    "v": "2",
    "ps": "VMess-Server",
    "add": "YOUR_SERVER_IP",
    "port": "443",
    "id": "uuid-here",
    "aid": "0",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "/vmess",
    "tls": "tls"
}
```

### VLESS Client

```
vless://uuid@YOUR_SERVER_IP:443?type=ws&security=tls&path=/vless#VLESS-Server
```

### Trojan Client

```
trojan://password@YOUR_SERVER_IP:443?type=ws&security=tls&path=/trojan#Trojan-Server
```

## Maintenance

### Automatic Tasks

-   Account cleanup: Every hour
-   Log rotation: Every 6 hours
-   Service restart: Daily at 3 AM
-   System updates: Weekly

### Manual Maintenance

```bash
# Update system packages
apt update && apt upgrade -y

# Clean old logs
find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;

# Backup configuration
tar -czf autoscript-backup-$(date +%Y%m%d).tar.gz \
  /opt/autoscript /etc/autoscript /usr/local/etc/xray

# Monitor resource usage
htop
df -h
free -h
```

## Uninstallation

```bash
# Stop all services
systemctl stop ssh dropbear xray

# Remove installed files
rm -rf /opt/autoscript
rm -rf /etc/autoscript
rm -f /usr/local/bin/autoscript
rm -f /usr/local/bin/ssh-account
rm -f /usr/local/bin/xray-client

# Remove Xray
rm -f /usr/local/bin/xray
rm -rf /usr/local/etc/xray

# Clean up logs
rm -rf /var/log/autoscript
rm -rf /var/log/xray

# Remove cron jobs
crontab -r

# Reset firewall (optional)
ufw --force reset
```

## Support

### Getting Help

-   Check this documentation first
-   Review log files for errors
-   Ensure system meets requirements
-   Verify internet connectivity

### Common Solutions

1. **Permission denied**: Ensure running as root
2. **Port conflicts**: Check for conflicting services
3. **Connection refused**: Verify firewall settings
4. **Service failed**: Check service logs

### Best Practices

-   Regular backups of configurations
-   Monitor system resources
-   Keep system updated
-   Review logs periodically
-   Test connections after changes

## Security Considerations

### Server Security

-   Use strong passwords
-   Enable fail2ban protection
-   Keep system updated
-   Monitor login attempts
-   Limit account validity periods

### Client Security

-   Don't share account credentials
-   Use TLS/SSL when available
-   Verify server certificates
-   Monitor data usage
-   Change passwords regularly

## Performance Optimization

### System Tuning

-   BBR congestion control enabled
-   TCP buffer optimization
-   Network stack tuning
-   File descriptor limits increased
-   Memory management optimized

### Monitoring

```bash
# Check system performance
htop
iotop
iftop

# Network statistics
ss -tuln
netstat -i

# Service status
systemctl status --all
```

## Updates

### Checking for Updates

```bash
# Check current version
autoscript --version

# Manual update process
cd /opt/autoscript
git pull origin main
```

### Changelog

-   v2.0.0: Complete rewrite with modern architecture
-   Enhanced security and performance
-   Improved account management
-   Better error handling and logging

---

**Note**: This documentation covers the basic installation and usage. For advanced configurations and troubleshooting, refer to the individual script documentation in the `/opt/autoscript/` directory.
EOF
