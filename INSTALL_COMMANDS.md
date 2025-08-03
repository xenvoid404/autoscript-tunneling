# Modern Tunneling Autoscript - Installation Commands

## 🚀 Quick Install Commands (Copy & Paste)

### Method 1: Ultra Quick Install via wget

```bash
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### Method 2: Ultra Quick Install via curl

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### Method 3: Download Main Installer

```bash
wget https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

### Method 4: One-liner with Main Installer

```bash
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh | sudo bash
```

### Method 5: Git Clone (Full Repository)

```bash
git clone https://github.com/your-repo/modern-tunneling-autoscript.git && cd modern-tunneling-autoscript && sudo ./install.sh
```

## ⚡ Post-Install Quick Commands

### Launch Management Panel

```bash
autoscript
```

### Create SSH Account (Quick)

```bash
ssh-account add testuser
```

### Create Xray Clients (Quick)

```bash
# VMess
xray-client add vmess user1

# VLESS
xray-client add vless user2

# Trojan
xray-client add trojan user3
```

### Check Installation Status

```bash
# Check services
systemctl status ssh dropbear xray

# Check firewall
ufw status

# Check accounts
ssh-account list

# Check system info
autoscript
```

## 🔧 Repository URLs

Replace `your-repo` with your actual GitHub username/organization:

### GitHub Repository

```
https://github.com/your-repo/modern-tunneling-autoscript
```

### Raw File URLs

```
# Quick installer
https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh

# Main installer
https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh

# Configuration files
https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/config/system.conf
https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/config/xray.json
```

## 📋 Pre-Installation Checklist

Before running installation commands, ensure:

-   [ ] **Root Access**: You have sudo or root privileges
-   [ ] **OS Support**: Debian 11+ or Ubuntu 22.04+
-   [ ] **Internet**: Stable internet connection
-   [ ] **Resources**: 512MB+ RAM, 2GB+ storage
-   [ ] **Clean System**: No conflicting services on ports 22, 80, 109, 143, 443, 8880

## 🎯 Installation Examples for Different Scenarios

### For VPS Fresh Install

```bash
# Update system first
apt update && apt upgrade -y

# Install autoscript
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### For Production Server

```bash
# Check system compatibility first
cat /etc/os-release
df -h
free -h

# Run installation
curl -fsSL https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### For Development/Testing

```bash
# Clone full repository for development
git clone https://github.com/your-repo/modern-tunneling-autoscript.git
cd modern-tunneling-autoscript

# Review code before installing
ls -la
cat README.md

# Install
sudo ./install.sh
```

## 🔄 Re-installation Commands

### Clean Re-install

```bash
# Stop services
sudo systemctl stop ssh dropbear xray

# Remove old installation
sudo rm -rf /opt/autoscript /etc/autoscript /usr/local/bin/{autoscript,ssh-account,xray-client}

# Fresh install
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### Update Installation

```bash
# Download and run installer (will detect existing installation)
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh | sudo bash
```

## 📱 Mobile/Terminal App Commands

For using in mobile terminal apps like Termux (if supported):

### Android Termux

```bash
# Install required packages
pkg update && pkg install wget curl

# Install autoscript (if running on VPS via SSH)
ssh root@your-vps "wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | bash"
```

### iOS iSH / a-Shell

```bash
# Connect to VPS and install
ssh root@your-vps
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | bash
```

## 🔍 Verification Commands

After installation, verify everything works:

```bash
# Check all services
systemctl status ssh dropbear xray

# Test management commands
autoscript --help 2>/dev/null || echo "Main menu available"
ssh-account list
xray-client list 2>/dev/null || echo "Xray client manager available"

# Check ports
netstat -tuln | grep -E ':(22|80|109|143|443|8880) '

# Check firewall
ufw status verbose

# Check logs
tail -5 /var/log/autoscript/autoscript.log
```

## 🚨 Emergency Commands

If something goes wrong:

### Service Issues

```bash
# Restart all services
sudo systemctl restart ssh dropbear xray

# Check service logs
sudo journalctl -u ssh -n 20
sudo journalctl -u xray -n 20

# Reset firewall (CAUTION!)
sudo ufw --force reset
```

### Complete Removal

```bash
# Stop everything
sudo systemctl stop ssh dropbear xray

# Remove autoscript
sudo rm -rf /opt/autoscript /etc/autoscript /var/log/autoscript
sudo rm -f /usr/local/bin/{autoscript,ssh-account,xray-client}

# Remove Xray
sudo rm -rf /usr/local/etc/xray /usr/local/bin/xray

# Clean crontab
sudo crontab -r
```

---

## 📝 Notes

1. **Replace URLs**: Change `your-repo` to your actual GitHub username
2. **Test First**: Try on test VPS before production
3. **Backup**: Backup existing configs before installing
4. **Monitor**: Check logs after installation
5. **Support**: Keep documentation handy

**Ready to install? Choose one of the quick install commands above and you're all set!** 🎉
