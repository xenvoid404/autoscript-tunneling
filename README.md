# Modern Tunneling Autoscript

Autoscript tunneling modern yang dirancang untuk setup layanan tunneling di VPS dengan fokus pada efisiensi, maintainability, dan production-ready.

## Supported Protocols

-   SSH (OpenSSH)
-   Dropbear SSH
-   Xray-core (VMess, VLESS, Trojan)
-   WebSocket (ws)
-   OpenVPN

## System Requirements

-   OS: Debian 11+ atau Ubuntu 22.04+
-   RAM: Minimal 512MB
-   Storage: Minimal 2GB free space
-   Root access

## Project Structure

```
autoscript/
├── install.sh              # Main installer script
├── config/                 # Configuration files
│   ├── system.conf         # System configuration
│   ├── ssh.conf           # SSH configuration template
│   ├── dropbear.conf      # Dropbear configuration template
│   └── xray.json          # Xray configuration template
├── scripts/                # Core scripts
│   ├── system/            # System setup scripts
│   │   ├── deps.sh        # Dependencies installer
│   │   ├── firewall.sh    # Firewall configuration
│   │   └── optimize.sh    # System optimization
│   ├── services/          # Service installation scripts
│   │   ├── ssh.sh         # SSH & Dropbear setup
│   │   ├── xray.sh        # Xray-core setup
│   │   └── websocket.sh   # WebSocket setup
│   └── accounts/          # Account management scripts
│       ├── ssh-account.sh  # SSH account management
│       ├── vmess-account.sh # VMess account management
│       ├── vless-account.sh # VLESS account management
│       └── trojan-account.sh # Trojan account management
├── utils/                  # Utility functions
│   ├── common.sh          # Common functions
│   ├── logger.sh          # Logging utilities
│   └── validator.sh       # Input validation
└── logs/                   # Log files
    └── install.log        # Installation log
```

## Installation

### Method 1: One-Command Install (Recommended)

```bash
# Quick install via wget
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### Method 2: Alternative One-Command Install

```bash
# Quick install via curl
curl -fsSL https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### Method 3: Manual Download and Install

```bash
# Download main installer
wget -O install.sh https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Method 4: Clone Repository

```bash
# Clone repository
git clone https://github.com/your-repo/modern-tunneling-autoscript.git
cd modern-tunneling-autoscript
sudo ./install.sh
```

## Features

-   Modern, clean code structure
-   Comprehensive logging
-   Input validation
-   Error handling
-   Production-ready configuration
-   Easy maintenance and updates

## License

MIT License
