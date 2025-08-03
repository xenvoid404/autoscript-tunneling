# Modern Tunneling Autoscript v3.0.0

A production-ready, modular tunneling solution for Debian 11+ and Ubuntu 22.04+ with separated Xray services, clean architecture, and professional deployment capabilities.

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh | bash
```

## ✨ Features

### Core Services
- **SSH Server** (Port 22) - Secure Shell access
- **Dropbear SSH** (Port 2222) - Lightweight SSH server
- **Separated Xray Services** - Individual systemd services for each protocol:
  - VMess (WebSocket: 55, gRPC: 1054, TCP: 1055)
  - VLESS (WebSocket: 58, gRPC: 1057, TCP: 1058)  
  - Trojan (WebSocket: 1060, gRPC: 1061, TCP: 1059)
- **Nginx Reverse Proxy** - HTTP/HTTPS (80/443) and gRPC (8443)

### Architecture Improvements
- **No Styled Logging** - Clean terminal output without colors
- **Modular Design** - Separated services for better maintainability
- **Production Ready** - Robust error handling and service management
- **Clean Code** - Removed unnecessary complexity and dependencies

## 📋 System Requirements

- **Operating System**: Debian 11+ or Ubuntu 22.04+
- **Architecture**: x86_64
- **RAM**: Minimum 512MB (1GB+ recommended)
- **Storage**: 2GB available space
- **Network**: Internet connection for installation

## 🛠️ Management Commands

### Service Management
```bash
# Control all services
autoscript-mgmt {start|stop|restart|status}

# Control Xray services only
xray-mgmt {start|stop|restart|status}
```

### Xray Client Management
```bash
# Add clients
xray-client add vmess username [uuid]
xray-client add vless username [uuid]
xray-client add trojan username [password]

# Remove clients
xray-client remove vmess username
xray-client remove vless username
xray-client remove trojan username

# List all clients
xray-client list

# Generate client configuration
xray-client config vmess username [server_ip]
xray-client config vless username [server_ip]
xray-client config trojan username [server_ip]
```

### SSH Account Management
```bash
# SSH account management (if available)
ssh-account add username [password] [days]
ssh-account delete username
ssh-account list
```

## 📁 Directory Structure

```
/opt/autoscript/           # Main installation directory
├── config/                # Configuration files
│   ├── vmess.json        # VMess service configuration
│   ├── vless.json        # VLESS service configuration
│   ├── trojan.json       # Trojan service configuration
│   ├── nginx.conf        # Nginx configuration
│   └── system.conf       # System configuration
├── scripts/               # Management scripts
│   ├── accounts/         # Account management
│   ├── services/         # Service setup scripts
│   ├── system/           # System utilities
│   └── xray-client.sh    # Xray client management
├── systemd/              # Systemd service files
└── utils/                # Utility functions

/etc/xray/                # Xray configuration directory
├── vmess.json           # VMess runtime configuration
├── vless.json           # VLESS runtime configuration
├── trojan.json          # Trojan runtime configuration
├── xray.crt            # SSL certificate
└── xray.key            # SSL private key

/etc/systemd/system/      # Systemd service files
├── xray-vmess.service   # VMess service unit
├── xray-vless.service   # VLESS service unit
└── xray-trojan.service  # Trojan service unit
```

## 🔧 Configuration

### Xray Services
Each Xray protocol runs as a separate systemd service:

- **VMess Service**: `xray-vmess.service`
- **VLESS Service**: `xray-vless.service`
- **Trojan Service**: `xray-trojan.service`

### Nginx Configuration
Nginx acts as a reverse proxy for:
- WebSocket connections (port 443)
- gRPC connections (port 8443)
- HTTP to HTTPS redirection (port 80)

### SSL Certificates
Self-signed certificates are automatically generated and stored in `/etc/xray/`.

## 📊 Port Usage

| Service | Protocol | Port | Type |
|---------|----------|------|------|
| SSH | SSH | 22 | TCP |
| Dropbear | SSH | 2222 | TCP |
| VMess | WebSocket | 55 | TCP |
| VMess | gRPC | 1054 | TCP |
| VMess | TCP | 1055 | TCP |
| VLESS | WebSocket | 58 | TCP |
| VLESS | gRPC | 1057 | TCP |
| VLESS | TCP | 1058 | TCP |
| Trojan | WebSocket | 1060 | TCP |
| Trojan | gRPC | 1061 | TCP |
| Trojan | TCP | 1059 | TCP |
| Nginx | HTTP | 80 | TCP |
| Nginx | HTTPS | 443 | TCP |
| Nginx | gRPC | 8443 | TCP |

## 🔒 Security Features

- **UFW Firewall** - Configured with necessary port rules
- **SSL/TLS Encryption** - Self-signed certificates for secure connections
- **Service Isolation** - Each protocol runs in separate systemd units
- **User Permissions** - Services run with minimal required privileges
- **Security Headers** - Nginx configured with security headers

## 📝 Logs

### System Logs
- Main logs: `/var/log/autoscript/`
- Service logs: `journalctl -u service-name`

### Xray Logs
- VMess: `/var/log/xray/vmess-access.log`, `/var/log/xray/vmess-error.log`
- VLESS: `/var/log/xray/vless-access.log`, `/var/log/xray/vless-error.log`
- Trojan: `/var/log/xray/trojan-access.log`, `/var/log/xray/trojan-error.log`

## 🔄 Updates and Maintenance

### Manual Service Control
```bash
# Individual service control
systemctl start/stop/restart/status xray-vmess
systemctl start/stop/restart/status xray-vless
systemctl start/stop/restart/status xray-trojan
systemctl start/stop/restart/status nginx
```

### Configuration Reload
After modifying configurations:
```bash
# Reload specific service
systemctl restart xray-vmess  # or xray-vless, xray-trojan

# Reload nginx
nginx -t && systemctl reload nginx
```

## 🆘 Troubleshooting

### Check Service Status
```bash
# Check all services
autoscript-mgmt status

# Check individual services
systemctl status xray-vmess
systemctl status xray-vless
systemctl status xray-trojan
systemctl status nginx
```

### View Logs
```bash
# Service logs
journalctl -u xray-vmess -f
journalctl -u xray-vless -f
journalctl -u xray-trojan -f

# Nginx logs
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

### Common Issues

1. **Service fails to start**: Check configuration syntax
   ```bash
   # Test Xray configuration
   xray run -test -config /etc/xray/vmess.json
   
   # Test Nginx configuration
   nginx -t
   ```

2. **Port conflicts**: Ensure no other services use the same ports
   ```bash
   ss -tuln | grep :PORT_NUMBER
   ```

3. **Certificate issues**: Regenerate SSL certificates
   ```bash
   # Manual certificate generation
   openssl genrsa -out /etc/xray/xray.key 2048
   openssl req -new -x509 -key /etc/xray/xray.key -out /etc/xray/xray.crt -days 3650
   ```

## 🤝 Contributing

This project focuses on:
- Clean, maintainable code
- Production-ready deployments
- Separated service architecture
- Professional logging and error handling

## 📄 License

MIT License - see LICENSE file for details.

## 🔗 Links

- **Repository**: https://github.com/xenvoid404/autoscript-tunneling
- **Issues**: https://github.com/xenvoid404/autoscript-tunneling/issues
- **Xray-core**: https://github.com/XTLS/Xray-core

---

**Version**: 3.0.0  
**Author**: Yuipedia  
**Last Updated**: 2024
