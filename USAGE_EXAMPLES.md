# Modern Tunneling Autoscript - Usage Examples

## Quick Installation Examples

### 🚀 Super Quick Install (One Command)

```bash
# Install with wget (recommended)
wget -O - https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash

# Alternative with curl
curl -fsSL https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/quick-install.sh | sudo bash
```

### 📦 Manual Installation

```bash
# Download installer
wget https://raw.githubusercontent.com/your-repo/modern-tunneling-autoscript/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### 🔄 Git Clone Method

```bash
git clone https://github.com/your-repo/modern-tunneling-autoscript.git
cd modern-tunneling-autoscript
sudo ./install.sh
```

## Post-Installation Usage

### 🎛️ Main Menu Access

```bash
# Launch interactive management panel
autoscript
```

### 👤 SSH Account Management

#### Create SSH Accounts

```bash
# Basic account creation (30 days validity)
ssh-account add testuser

# Custom validity period
ssh-account add testuser2 "" 60  # 60 days

# With custom password
ssh-account add testuser3 "MySecurePassword123" 30
```

#### Manage SSH Accounts

```bash
# List all accounts
ssh-account list

# Show account details
ssh-account show testuser

# Extend account validity
ssh-account extend testuser 30

# Change password
ssh-account password testuser

# Delete account
ssh-account delete testuser

# Cleanup expired accounts
ssh-account cleanup
```

### 🌐 Xray Client Management

#### Create Xray Clients

```bash
# Create VMess client
xray-client add vmess user1

# Create VLESS client
xray-client add vless user2

# Create Trojan client
xray-client add trojan user3

# With custom UUID (VMess/VLESS)
xray-client add vmess user4 --uuid 12345678-1234-1234-1234-123456789abc

# With custom password (Trojan)
xray-client add trojan user5 --password myTrojanPassword
```

#### Manage Xray Clients

```bash
# List all clients
xray-client list

# Generate client configuration
xray-client config user1 YOUR_SERVER_IP

# Remove client
xray-client remove user1
```

## Configuration Examples

### 📱 Client App Configurations

#### HTTP Injector/Custom (SSH)

```
Connection Type: SSH
Server Host: YOUR_SERVER_IP
Server Port: 22 (or 109 for Dropbear)
Username: testuser
Password: generated_password

Payload/SNI: [Host]
Request Method: GET
```

#### HTTP Injector (WebSocket)

```
Connection Type: SSH
Server Host: YOUR_SERVER_IP
Server Port: 8880
Username: testuser
Password: generated_password

WebSocket Settings:
- Host: YOUR_SERVER_IP:8880
- Path: /ws
```

#### V2rayNG (VMess)

```json
{
    "v": "2",
    "ps": "VMess-Server",
    "add": "YOUR_SERVER_IP",
    "port": "443",
    "id": "client-uuid-here",
    "aid": "0",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "/vmess",
    "tls": "tls"
}
```

#### V2rayNG (VLESS)

```
vless://client-uuid@YOUR_SERVER_IP:443?type=ws&security=tls&path=/vless#VLESS-Config
```

#### Clash (Trojan)

```yaml
proxies:
    - name: 'Trojan-Server'
      type: trojan
      server: YOUR_SERVER_IP
      port: 443
      password: trojan-password
      network: ws
      ws-opts:
          path: /trojan
```

## System Management Examples

### 🔧 Service Management

```bash
# Check service status
systemctl status ssh
systemctl status dropbear
systemctl status xray

# Restart services
systemctl restart ssh
systemctl restart dropbear
systemctl restart xray

# View service logs
journalctl -u ssh -f
journalctl -u xray -f
```

### 🔥 Firewall Management

```bash
# Check firewall status
ufw status verbose

# Allow custom port
ufw allow 8080/tcp

# Block IP address
ufw deny from 192.168.1.100

# Reset firewall (CAUTION!)
ufw --force reset
```

### 📊 System Monitoring

```bash
# Check system resources
htop
df -h
free -h

# Network connections
ss -tuln
netstat -i

# Check active accounts
who
last
```

### 📝 Log Management

```bash
# View autoscript logs
tail -f /var/log/autoscript/autoscript.log
tail -f /var/log/autoscript/error.log
tail -f /var/log/autoscript/access.log

# View Xray logs
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# Clean large logs
find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \;
```

## Advanced Usage

### 🔄 Backup & Restore

```bash
# Create full backup
tar -czf autoscript-backup-$(date +%Y%m%d).tar.gz \
  /opt/autoscript \
  /etc/autoscript \
  /usr/local/etc/xray

# Backup accounts only
cp /etc/autoscript/accounts/* /backup/

# Restore from backup
tar -xzf autoscript-backup-20231201.tar.gz -C /
systemctl restart ssh dropbear xray
```

### 📈 Performance Tuning

```bash
# Check TCP congestion control
sysctl net.ipv4.tcp_congestion_control

# Monitor network performance
iftop
nload

# Check system optimization
cat /proc/sys/net/ipv4/tcp_window_scaling
cat /proc/sys/net/core/rmem_max
```

### 🔐 Security Hardening

```bash
# Check fail2ban status
fail2ban-client status
fail2ban-client status ssh

# View banned IPs
fail2ban-client get ssh banned

# Unban IP
fail2ban-client set ssh unbanip 192.168.1.100

# Check SSH authentication logs
grep "Failed password" /var/log/auth.log
grep "Accepted password" /var/log/auth.log
```

## Troubleshooting Examples

### 🐛 Common Issues

#### Installation Problems

```bash
# Check OS compatibility
cat /etc/os-release

# Test internet connectivity
ping -c 4 github.com
curl -I https://github.com

# Check available space
df -h
du -sh /opt /etc /var/log

# Debug installation
bash -x install.sh
```

#### Service Issues

```bash
# SSH not working
systemctl status ssh
sshd -t  # Test configuration
tail -f /var/log/auth.log

# Xray not starting
systemctl status xray
xray -test -config /usr/local/etc/xray/config.json
tail -f /var/log/xray/error.log

# Port conflicts
netstat -tuln | grep :22
lsof -i :443
```

#### Connection Problems

```bash
# Test SSH connection
ssh -v testuser@YOUR_SERVER_IP

# Test specific ports
telnet YOUR_SERVER_IP 22
telnet YOUR_SERVER_IP 443

# Check firewall blocking
ufw status numbered
iptables -L -n
```

#### Account Issues

```bash
# Check account database
cat /etc/autoscript/accounts/ssh_accounts.txt

# Verify system user
id testuser
grep testuser /etc/passwd

# Check account expiry
ssh-account show testuser
```

### 🔧 Quick Fixes

```bash
# Reset SSH configuration
cp /opt/autoscript/config/ssh.conf /etc/ssh/sshd_config
systemctl restart ssh

# Regenerate Xray config
bash /opt/autoscript/scripts/services/xray.sh

# Fix permissions
chmod -R 755 /opt/autoscript
chmod 600 /etc/autoscript/accounts/*

# Restart all services
systemctl restart ssh dropbear xray
```

## Automation Examples

### 📅 Cron Jobs

```bash
# Auto cleanup (already included)
0 * * * * /opt/autoscript/scripts/accounts/ssh-account.sh cleanup

# Daily backup
0 2 * * * tar -czf /backup/autoscript-$(date +\%Y\%m\%d).tar.gz /etc/autoscript/accounts

# Weekly log cleanup
0 3 * * 0 find /var/log -name "*.log" -mtime +7 -delete

# Monthly account report
0 8 1 * * /opt/autoscript/scripts/accounts/ssh-account.sh list > /var/log/monthly-accounts.txt
```

### 🔄 Batch Operations

```bash
# Create multiple accounts
for user in user{1..10}; do
  ssh-account add "$user" "" 30
done

# Mass account extension
for user in $(ssh-account list | awk 'NR>2 {print $1}'); do
  ssh-account extend "$user" 30
done

# Backup all configurations
mkdir -p /backup/$(date +%Y%m%d)
cp -r /opt/autoscript /backup/$(date +%Y%m%d)/
cp -r /etc/autoscript /backup/$(date +%Y%m%d)/
```

## Integration Examples

### 🌐 Web Panel Integration

```bash
# Install web server (optional)
apt install nginx php-fpm

# Create API endpoint (example)
echo '<?php
$action = $_GET["action"];
$user = $_GET["user"];
if($action == "add") {
  system("ssh-account add $user");
}
?>' > /var/www/html/api.php
```

### 📊 Monitoring Integration

```bash
# Prometheus metrics (example)
echo "autoscript_accounts_total $(ssh-account list | wc -l)" > /var/lib/node_exporter/autoscript.prom

# Grafana dashboard data
ssh-account list --json > /var/www/html/accounts.json
```

---

**Note**: Replace `YOUR_SERVER_IP` with your actual server IP address and `your-repo` with your GitHub username/organization in all examples above.
