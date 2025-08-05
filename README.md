# Autoscript Tunneling

Autoscript untuk instalasi otomatis layanan tunneling (SSH, Dropbear, WebSocket, Xray, OpenVPN) pada server Debian 11+ dan Ubuntu 22+.

## 🚀 Fitur

- **SSH & Dropbear**: Konfigurasi SSH yang aman dengan Dropbear sebagai alternatif
- **Xray Core**: Support VMess, VLESS, dan Trojan dengan multiple services
- **OpenVPN**: Server OpenVPN dengan konfigurasi TCP/UDP/SSL
- **Certificate Management**: Otomatis generate dan renew SSL certificate
- **Firewall**: Konfigurasi iptables dengan fail2ban
- **WebSocket**: Support WebSocket proxy untuk tunneling
- **Validation**: Script validasi untuk mengecek keberhasilan instalasi

## 📋 Persyaratan Sistem

- **OS**: Debian 11+ atau Ubuntu 22+
- **Architecture**: x86_64
- **RAM**: Minimal 512MB
- **Storage**: Minimal 10GB
- **Network**: Koneksi internet stabil
- **Virtualization**: Tidak support OpenVZ

## 🔧 Instalasi

### Quick Install

```bash
# Update sistem dan install dependencies
apt update -y && apt install -y curl jq wget screen build-essential

# Download dan jalankan installer
curl -sSfL https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install-improved.sh -o install-improved.sh
chmod +x install-improved.sh
screen -S yuipedia ./install-improved.sh
```

### Manual Install

```bash
# Clone repository
git clone https://github.com/xenvoid404/autoscript-tunneling.git
cd autoscript-tunneling

# Set environment variables (opsional)
export CF_EMAIL="your-email@domain.com"
export CF_API="your-cloudflare-api-key"
export CF_ZONE="your-cloudflare-zone-id"

# Jalankan installer
chmod +x install-improved.sh
./install-improved.sh
```

## ⚙️ Konfigurasi

### Environment Variables

Buat file `.env` atau set environment variables:

```bash
# Cloudflare Configuration (untuk auto domain)
export CF_EMAIL="your-email@domain.com"
export CF_API="your-cloudflare-api-key"
export CF_ZONE="your-cloudflare-zone-id"

# Custom Ports (opsional)
export SSH_PORT=22
export DROPBEAR_PORT=90
export OPENVPN_TCP_PORT=1194
export OPENVPN_UDP_PORT=25000
```

### Custom Configuration

Edit file `config/environment.conf` untuk mengubah konfigurasi default:

```bash
# Port Configuration
SSH_PORT=22
DROPBEAR_PORT=90
OPENVPN_TCP_PORT=1194
OPENVPN_UDP_PORT=25000
XRAY_VMESS_PORT=2048
XRAY_VLESS_PORT=4096
XRAY_TROJAN_PORT=1024

# Service Configuration
XRAY_SERVICES=("spectrum" "quantix" "cipheron")
OPENVPN_SERVICES=("server-tcp-1194" "server-udp-25000")
```

## 🔍 Validasi Instalasi

Setelah instalasi selesai, jalankan script validasi:

```bash
# Jalankan validasi
bash bin/validate-installation.sh

# Atau jalankan validasi individual
bash bin/validate-installation.sh --certificate
bash bin/validate-installation.sh --xray
bash bin/validate-installation.sh --openvpn
bash bin/validate-installation.sh --ssh
bash bin/validate-installation.sh --firewall
```

## 📁 Struktur Direktori

```
autoscript-tunneling/
├── install-improved.sh          # Main installer
├── lib/
│   └── common.sh               # Common functions
├── config/
│   ├── environment.conf        # Environment configuration
│   ├── dropbear               # Dropbear configuration
│   └── haproxy.cfg           # HAProxy configuration
├── installer/
│   ├── certificate.sh         # Certificate installer
│   ├── xray-core.sh          # Xray installer
│   ├── openvpn.sh            # OpenVPN installer
│   └── ssh-vpn.sh            # SSH installer
├── xray/
│   ├── spectrum.service       # Xray VMess service
│   ├── quantix.service        # Xray VLESS service
│   ├── cipheron.service       # Xray Trojan service
│   └── layers.zip            # Xray configurations
├── bin/
│   ├── validate-installation.sh # Validation script
│   ├── ws-epro               # WebSocket proxy
│   └── neofetch              # System info
├── server/
│   └── ipserver              # IP server configuration
└── README.md                 # Documentation
```

## 🛠️ Troubleshooting

### Common Issues

1. **Certificate Error**
   ```bash
   # Check certificate status
   openssl x509 -in /etc/certificates/fullchain.crt -text -noout
   
   # Reinstall certificate
   bash installer/certificate-improved.sh
   ```

2. **Service Not Starting**
   ```bash
   # Check service status
   systemctl status spectrum quantix cipheron
   
   # Check logs
   journalctl -u spectrum -f
   ```

3. **Port Already in Use**
   ```bash
   # Check port usage
   netstat -tuln | grep :80
   
   # Kill process using port
   fuser -k 80/tcp
   ```

4. **Firewall Issues**
   ```bash
   # Reset iptables
   iptables -F
   iptables -X
   bash server/ipserver
   ```

### Log Files

- **Xray**: `/var/log/xray/`
- **OpenVPN**: `/var/log/openvpn/`
- **SSH**: `/var/log/auth.log`
- **System**: `/var/log/syslog`

## 🔒 Keamanan

### Best Practices

1. **Change Default Ports**
   ```bash
   # Edit config/environment.conf
   SSH_PORT=2222
   DROPBEAR_PORT=2223
   ```

2. **Enable Fail2ban**
   ```bash
   # Check fail2ban status
   systemctl status fail2ban
   
   # View banned IPs
   fail2ban-client status sshd
   ```

3. **Regular Updates**
   ```bash
   # Update system
   apt update && apt upgrade -y
   
   # Update Xray
   bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
   ```

4. **Backup Configuration**
   ```bash
   # Backup configs
   tar -czf backup-$(date +%Y%m%d).tar.gz /etc/openvpn /etc/default/layers /etc/certificates
   ```

## 📊 Monitoring

### Service Status

```bash
# Check all services
systemctl status spectrum quantix cipheron openvpn-server@server-tcp-1194 ssh

# Check ports
netstat -tuln | grep -E ':(80|443|1194|25000|2048|4096)'
```

### Performance Monitoring

```bash
# Check resource usage
htop
df -h
free -h

# Check network
iftop
nethogs
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📝 Changelog

### Version 2.0
- ✅ Improved error handling
- ✅ Added validation script
- ✅ Modular configuration
- ✅ Better security practices
- ✅ Comprehensive documentation

### Version 1.0
- ✅ Initial release
- ✅ Basic installation
- ✅ Service configuration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Xray](https://github.com/XTLS/Xray) - Core proxy
- [OpenVPN](https://openvpn.net/) - VPN solution
- [acme.sh](https://github.com/acmesh-official/acme.sh) - Certificate management
- [fail2ban](https://www.fail2ban.org/) - Intrusion prevention

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/xenvoid404/autoscript-tunneling/issues)
- **Discussions**: [GitHub Discussions](https://github.com/xenvoid404/autoscript-tunneling/discussions)
- **Email**: support@domain.com

---

**⚠️ Disclaimer**: Script ini hanya untuk tujuan edukasi dan testing. Gunakan dengan bijak dan sesuai dengan hukum yang berlaku di wilayah Anda.