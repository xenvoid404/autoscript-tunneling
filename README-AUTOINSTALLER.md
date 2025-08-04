# Modern Tunneling Autoinstaller v4.0.0

## Overview

Modern Tunneling Autoinstaller adalah script instalasi lengkap yang dapat menginstal semua konfigurasi tunneling dalam 1 kali perintah. Script ini dirancang untuk production-ready dengan error handling yang komprehensif, validasi yang ketat, dan konfigurasi yang lengkap.

## Fitur Utama

### ✅ Production-Ready Features
- **One-command installation** - Instalasi lengkap dalam 1 perintah
- **Comprehensive error handling** - Penanganan error yang menyeluruh
- **Automatic validation** - Validasi otomatis semua komponen
- **System optimization** - Optimasi sistem untuk performa maksimal
- **Security hardening** - Pengaturan keamanan yang ketat
- **Health monitoring** - Monitoring kesehatan sistem

### 🔧 Services Included
- **SSH & Dropbear SSH** - Akses remote yang aman
- **Xray-core (VMess, VLESS, Trojan)** - Protokol tunneling modern
- **Nginx WebServer** - Web server dengan WebSocket support
- **UFW Firewall** - Firewall yang dikonfigurasi otomatis
- **SSL Certificates** - Sertifikat SSL otomatis

### 📊 Management Tools
- **autoscript-mgmt** - Manajemen semua layanan
- **xray-mgmt** - Manajemen khusus Xray
- **xray-client** - Manajemen client Xray
- **Health checks** - Pemeriksaan kesehatan sistem

## Quick Install

### Metode 1: One-command Installation
```bash
curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/autoinstaller.sh | bash
```

### Metode 2: Download dan Install
```bash
# Download script
wget https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/autoinstaller.sh

# Set executable permission
chmod +x autoinstaller.sh

# Run installation
sudo ./autoinstaller.sh install
```

## System Requirements

### ✅ Supported Operating Systems
- **Ubuntu 22.04+** (Recommended)
- **Debian 11+** (Recommended)
- **Other Debian-based distributions**

### 🔧 Hardware Requirements
- **CPU**: 1 core minimum, 2+ cores recommended
- **RAM**: 512MB minimum, 1GB+ recommended
- **Storage**: 500MB minimum free space
- **Network**: Stable internet connection

### 📋 Prerequisites
- Root access (sudo privileges)
- Internet connectivity
- Fresh system installation (recommended)

## Installation Process

### 1. Pre-Installation Checks
- ✅ Root privilege verification
- ✅ OS compatibility check
- ✅ Internet connectivity test
- ✅ Disk space verification
- ✅ System resource check

### 2. Installation Steps
- 📁 Create directory structure
- 📥 Download all required files
- 🔧 Install system dependencies
- ⚡ Install Xray-core
- 🔐 Generate SSL certificates
- ⚙️ Configure Xray services
- 🌐 Setup Nginx web server
- 🔥 Configure firewall (UFW)
- ⚡ Optimize system performance
- 🛠️ Create management scripts
- 🚀 Start all services

### 3. Post-Installation Validation
- ✅ File integrity check
- ✅ Configuration validation
- ✅ Service status verification
- ✅ Network connectivity test
- ✅ SSL certificate validation

## Usage

### Basic Commands

#### Installation
```bash
# Complete installation
sudo ./autoinstaller.sh install

# Check installation status
sudo ./autoinstaller.sh status

# Run health check
sudo ./autoinstaller.sh health

# Show installation info
sudo ./autoinstaller.sh info
```

#### Service Management
```bash
# Start all services
sudo autoscript-mgmt start

# Stop all services
sudo autoscript-mgmt stop

# Restart all services
sudo autoscript-mgmt restart

# Check service status
sudo autoscript-mgmt status

# Run health check
sudo autoscript-mgmt health
```

#### Xray Management
```bash
# Start Xray services
sudo xray-mgmt start

# Stop Xray services
sudo xray-mgmt stop

# Restart Xray services
sudo xray-mgmt restart

# Check Xray status
sudo xray-mgmt status
```

#### Client Management
```bash
# Add VMess client
sudo xray-client add vmess username

# Add VLESS client
sudo xray-client add vless username

# Add Trojan client
sudo xray-client add trojan username

# List all clients
sudo xray-client list

# Remove client
sudo xray-client remove username
```

## Configuration

### Port Configuration
| Service | Protocol | Port | Description |
|---------|----------|------|-------------|
| SSH | TCP | 22 | Secure Shell access |
| Dropbear | TCP | 2222 | Alternative SSH |
| HTTP | TCP | 80 | Web server |
| HTTPS | TCP | 443 | Secure web server |
| VMess WS | TCP | 55 | VMess WebSocket |
| VLESS WS | TCP | 58 | VLESS WebSocket |
| VMess gRPC | TCP | 1054 | VMess gRPC |
| VMess TCP | TCP | 1055 | VMess TCP |
| VLESS gRPC | TCP | 1057 | VLESS gRPC |
| VLESS TCP | TCP | 1058 | VLESS TCP |
| Trojan TCP | TCP | 1059 | Trojan TCP |
| Trojan WS | TCP | 1060 | Trojan WebSocket |
| Trojan gRPC | TCP | 1061 | Trojan gRPC |
| Nginx gRPC | TCP | 8443 | Nginx gRPC |

### Directory Structure
```
/opt/autoscript/           # Main installation directory
├── config/                # Configuration files
├── scripts/               # Management scripts
├── utils/                 # Utility functions
└── systemd/              # Systemd service files

/etc/autoscript/          # System configuration
├── accounts/             # User accounts
└── system.conf          # System settings

/etc/xray/               # Xray configuration
├── vmess.json          # VMess configuration
├── vless.json          # VLESS configuration
├── trojan.json         # Trojan configuration
├── outbounds.json      # Outbound rules
├── rules.json          # Routing rules
└── ssl/                # SSL certificates
    ├── cert.pem        # SSL certificate
    └── key.pem         # SSL private key

/var/log/autoscript/     # Log files
└── autoscript-install.log

/usr/local/bin/         # Management scripts
├── autoscript-mgmt     # Main management script
├── xray-mgmt          # Xray management
└── xray-client        # Client management
```

## Testing

### Run Complete Test Suite
```bash
sudo ./test-autoinstaller.sh test
```

### Run Specific Tests
```bash
# System compatibility tests
sudo ./test-autoinstaller.sh system

# File integrity tests
sudo ./test-autoinstaller.sh files

# Configuration validation tests
sudo ./test-autoinstaller.sh config

# Service functionality tests
sudo ./test-autoinstaller.sh services

# Network connectivity tests
sudo ./test-autoinstaller.sh network

# Security tests
sudo ./test-autoinstaller.sh security

# Performance tests
sudo ./test-autoinstaller.sh performance
```

## Troubleshooting

### Common Issues

#### Installation Fails
```bash
# Check error logs
sudo cat /var/log/autoscript-error.log

# Check installation log
sudo cat /var/log/autoscript-install.log

# Re-run installation
sudo ./autoinstaller.sh install
```

#### Services Not Starting
```bash
# Check service status
sudo autoscript-mgmt status

# Check specific service
sudo systemctl status xray-vmess
sudo systemctl status xray-vless
sudo systemctl status xray-trojan
sudo systemctl status nginx

# Restart services
sudo autoscript-mgmt restart
```

#### Port Issues
```bash
# Check port usage
sudo ss -tuln | grep -E ':(22|80|443|55|58)'

# Check firewall status
sudo ufw status

# Restart firewall
sudo ufw --force enable
```

#### SSL Certificate Issues
```bash
# Check SSL certificate
sudo openssl x509 -in /etc/xray/ssl/cert.pem -noout -text

# Regenerate SSL certificate
sudo rm -f /etc/xray/ssl/cert.pem /etc/xray/ssl/key.pem
sudo ./autoinstaller.sh install
```

### Log Files
- **Installation Log**: `/var/log/autoscript-install.log`
- **Error Log**: `/var/log/autoscript-error.log`
- **Test Log**: `/var/log/autoscript-test.log`
- **Xray Logs**: `/var/log/xray/`
- **Nginx Logs**: `/var/log/nginx/`

## Security Features

### 🔒 Security Hardening
- **Automatic firewall configuration** (UFW)
- **SSL certificate generation** with proper permissions
- **Service isolation** with separate systemd units
- **File permission hardening** (600 for keys, 644 for certs)
- **Network optimization** with BBR congestion control

### 🛡️ Best Practices
- **Root-only installation** for security
- **Automatic service restart** on failure
- **Comprehensive logging** for monitoring
- **Health checks** for system monitoring
- **Cleanup procedures** on installation failure

## Performance Optimization

### ⚡ System Optimizations
- **Kernel parameter tuning** for network performance
- **File descriptor limits** increase (65536)
- **BBR congestion control** for better throughput
- **TCP optimization** for reduced latency
- **Memory and CPU optimization**

### 📊 Monitoring
- **Real-time service monitoring**
- **Resource usage tracking**
- **Network performance metrics**
- **Health check automation**

## Updates and Maintenance

### 🔄 Updating Autoinstaller
```bash
# Download latest version
wget https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/autoinstaller.sh

# Update permissions
chmod +x autoinstaller.sh

# Re-run installation
sudo ./autoinstaller.sh install
```

### 🧹 Maintenance Commands
```bash
# Check system health
sudo autoscript-mgmt health

# View logs
sudo tail -f /var/log/autoscript-install.log

# Clean old logs
sudo find /var/log/autoscript -name "*.log" -mtime +30 -delete

# Update system packages
sudo apt update && sudo apt upgrade -y
```

## Support

### 📞 Getting Help
1. **Check logs first**: `/var/log/autoscript-install.log`
2. **Run health check**: `sudo autoscript-mgmt health`
3. **Run test suite**: `sudo ./test-autoinstaller.sh test`
4. **Check service status**: `sudo autoscript-mgmt status`

### 🔗 Useful Commands
```bash
# Quick status check
sudo autoscript-mgmt health

# View all logs
sudo journalctl -u xray-vmess -f
sudo journalctl -u xray-vless -f
sudo journalctl -u xray-trojan -f

# Check network
sudo ss -tuln
sudo netstat -tuln

# Check disk usage
df -h
du -sh /opt/autoscript /etc/xray
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Changelog

### v4.0.0 (Latest)
- ✅ Complete rewrite with production-ready features
- ✅ Comprehensive error handling and validation
- ✅ Automatic SSL certificate generation
- ✅ System optimization and security hardening
- ✅ Health monitoring and testing suite
- ✅ One-command installation process
- ✅ Management scripts for easy administration

### v3.0.0
- ✅ Basic installation script
- ✅ Xray-core integration
- ✅ Nginx configuration
- ✅ Basic service management

---

**Note**: This autoinstaller is designed for production use with comprehensive error handling, validation, and security features. Always test in a safe environment before deploying to production.