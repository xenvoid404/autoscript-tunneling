# Yuipedia Tunneling Autoscript

> Production-ready tunneling solution untuk mengubah kuota game/edukasi menjadi kuota reguler menggunakan berbagai protokol tunneling modern.

## 🚀 Features

- **SSH Tunneling** - OpenSSH Server & Dropbear SSH
- **Xray-core Protocols** - VMess, VLESS, Trojan
- **WebSocket Tunneling** - ws, wss protocols
- **Advanced Account Management** - Create, update, delete accounts
- **Production Ready** - Comprehensive logging, error handling, input validation
- **Auto Optimization** - System optimization dan firewall configuration
- **Multi Protocol Support** - Berbagai protokol untuk berbagai kebutuhan

## 📋 System Requirements

### Operating System
- **Debian 11+** (Bullseye atau newer)
- **Ubuntu 22.04+** (Jammy Jellyfish atau newer)

### Hardware Requirements
- **RAM**: Minimal 512MB (1GB recommended)
- **Storage**: Minimal 2GB free space
- **CPU**: 1 core (2 cores recommended)
- **Network**: Public IP address

### Prerequisites
- Root access ke server
- Koneksi internet yang stabil
- Basic knowledge of Linux commands

## 🛡️ Supported Protocols

### SSH Tunneling
- **OpenSSH Server** - Port 22 (default)
- **Dropbear SSH** - Port 109
- **Dropbear WebSocket** - Port 143
- **SSH WebSocket Tunnel** - Port 8880

### Xray-core Protocols
- **VMess TCP** - Port 80
- **VMess WebSocket+TLS** - Port 443
- **VLESS TCP** - Port 80
- **VLESS WebSocket+TLS** - Port 443
- **Trojan TCP+TLS** - Port 443
- **Trojan WebSocket+TLS** - Port 443

## ⚡ Quick Installation

### Method 1: One-Command Install (Recommended)

```bash
# Install dengan wget (recommended)
wget -O - https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/quick-install.sh | sudo bash

# Alternative dengan curl
curl -fsSL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/quick-install.sh | sudo bash
```

### Method 2: Manual Installation

```bash
# Download installer
wget https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Method 3: Git Clone Method

```bash
git clone https://github.com/xenvoid404/autoscript-tunneling.git
cd autoscript-tunneling
sudo ./install.sh
```

## 📁 Project Structure

```
autoscript/
├── install.sh              # Main installer script
├── quick-install.sh         # Quick installer
├── config/                  # Configuration files
│   ├── system.conf          # System configuration
│   ├── ssh.conf            # SSH configuration template
│   ├── dropbear.conf       # Dropbear configuration template
│   └── xray.json           # Xray configuration template
├── scripts/                 # Core scripts
│   ├── system/             # System setup scripts
│   │   ├── deps.sh         # Dependencies installer
│   │   ├── firewall.sh     # Firewall configuration
│   │   └── optimize.sh     # System optimization
│   ├── services/           # Service installation scripts
│   │   ├── ssh.sh          # SSH & Dropbear setup
│   │   ├── xray.sh         # Xray-core setup
│   │   └── websocket.sh    # WebSocket setup
│   └── accounts/           # Account management scripts
│       ├── ssh-account.sh   # SSH account management
│       ├── vmess-account.sh # VMess account management
│       ├── vless-account.sh # VLESS account management
│       └── trojan-account.sh # Trojan account management
├── utils/                   # Utility functions
│   ├── common.sh           # Common functions
│   ├── logger.sh           # Logging utilities
│   └── validator.sh        # Input validation
└── logs/                    # Log files
    └── install.log         # Installation log
```

## 🎛️ Usage

### Main Menu Access

```bash
# Launch interactive management panel
autoscript
```

### SSH Account Management

```bash
# Create SSH account (30 days validity)
ssh-account add username

# Create SSH account dengan custom validity
ssh-account add username2 "" 60  # 60 days

# List all SSH accounts
ssh-account list

# Delete SSH account
ssh-account del username

# Extend account validity
ssh-account renew username 30
```

### VMess Account Management

```bash
# Create VMess account
vmess-account add username

# List VMess accounts
vmess-account list

# Delete VMess account
vmess-account del username

# Show VMess config
vmess-account show username
```

### VLESS Account Management

```bash
# Create VLESS account
vless-account add username

# List VLESS accounts
vless-account list

# Delete VLESS account
vless-account del username

# Show VLESS config
vless-account show username
```

### Trojan Account Management

```bash
# Create Trojan account
trojan-account add username

# List Trojan accounts
trojan-account list

# Delete Trojan account
trojan-account del username

# Show Trojan config
trojan-account show username
```

## 🔧 Management Commands

### System Status

```bash
# Check all services status
autoscript status

# Check specific service
systemctl status ssh
systemctl status dropbear
systemctl status xray
```

### Log Management

```bash
# View installation logs
tail -f /var/log/autoscript/install.log

# View SSH logs
tail -f /var/log/auth.log

# View Xray logs
journalctl -u xray -f
```

### Configuration Update

```bash
# Update system configuration
autoscript config

# Restart all services
autoscript restart

# Update to latest version
autoscript update
```

## 🛠️ Troubleshooting

### Common Issues

1. **Port sudah digunakan**
   ```bash
   # Check port usage
   netstat -tulpn | grep :PORT_NUMBER
   
   # Kill process using port
   sudo kill -9 PID
   ```

2. **Service tidak bisa start**
   ```bash
   # Check service status
   systemctl status SERVICE_NAME
   
   # Check logs
   journalctl -u SERVICE_NAME -f
   ```

3. **Koneksi timeout**
   ```bash
   # Check firewall
   ufw status
   
   # Allow port
   ufw allow PORT_NUMBER
   ```

### Reset Installation

```bash
# Remove all installed components
autoscript uninstall

# Clean installation
rm -rf /opt/autoscript /etc/autoscript /var/log/autoscript
```

## 📊 Performance Optimization

Script ini sudah include optimasi sistem:

- **TCP BBR** congestion control
- **Kernel parameters** tuning
- **Network buffers** optimization
- **System limits** adjustment
- **Automatic cleanup** via cron jobs

## 🔒 Security Features

- **Firewall** configuration otomatis
- **Fail2ban** protection
- **SSH key** authentication support
- **Account expiration** management
- **Traffic monitoring** and logging

## 📝 License

MIT License - see LICENSE file for details

## 👨‍💻 Author

**Yuipedia**
- GitHub: [@xenvoid404](https://github.com/xenvoid404)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## ⭐ Support

Jika script ini berguna, please give a star ⭐ pada repository ini!

---

**Version**: 2.0.0  
**Last Updated**: 2024  
**Tested On**: Debian 11+, Ubuntu 22.04+
