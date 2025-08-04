# Autoscript Tunneling untuk Debian/Ubuntu

Script otomatis untuk instalasi dan konfigurasi layanan SSH tunneling menggunakan OpenSSH dan Dropbear pada sistem Debian 11/12 dan Ubuntu 22/24.

## 🚀 Fitur

- ✅ **Instalasi Otomatis**: OpenSSH dan Dropbear dengan satu perintah
- ✅ **Deteksi Port Conflict**: Otomatis menangani bentrokan port antara layanan
- ✅ **Multi-Port Support**: Konfigurasi multiple port untuk setiap layanan
- ✅ **Auto-Start**: Semua layanan aktif otomatis saat boot
- ✅ **Backup & Restore**: Backup otomatis konfigurasi sebelum perubahan
- ✅ **Firewall Integration**: Otomatis konfigurasi UFW jika aktif
- ✅ **Production Ready**: Siap digunakan di VPS fresh install

## 📋 Sistem yang Didukung

- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **Ubuntu**: 22.04 LTS, 24.04 LTS

## 📦 Port Configuration

### OpenSSH
- **Port utama**: 22, 80, 443, 444
- **Fallback**: Otomatis skip port yang sudah digunakan

### Dropbear
- **Port utama**: 90, 143, 80, 443
- **Port alternatif**: 8080, 8443, 9090, 9443 (jika port utama tidak tersedia)

> **Catatan**: Script secara otomatis mendeteksi port yang sudah digunakan dan menyesuaikan konfigurasi untuk menghindari conflict.

## 🛠️ Instalasi

### Quick Install (Recommended)

```bash
# Download dan jalankan script
wget https://raw.githubusercontent.com/your-repo/autoscript-tunnel.sh
chmod +x autoscript-tunnel.sh
sudo ./autoscript-tunnel.sh
```

### Manual Install

```bash
# Clone repository
git clone https://github.com/your-repo/autoscript-tunnel.git
cd autoscript-tunnel

# Jalankan script
sudo ./autoscript-tunnel.sh
```

## 📖 Cara Penggunaan

### 1. Jalankan Script

```bash
sudo ./autoscript-tunnel.sh
```

### 2. Tunggu Proses Instalasi

Script akan otomatis:
- Mengecek sistem operasi
- Update package repository
- Install OpenSSH dan Dropbear
- Konfigurasi port dan layanan
- Enable auto-start services
- Tampilkan informasi koneksi

### 3. Koneksi SSH

Setelah instalasi selesai, Anda dapat terhubung menggunakan:

```bash
# Menggunakan OpenSSH
ssh root@YOUR_SERVER_IP -p 22
ssh root@YOUR_SERVER_IP -p 80
ssh root@YOUR_SERVER_IP -p 443
ssh root@YOUR_SERVER_IP -p 444

# Menggunakan Dropbear
ssh root@YOUR_SERVER_IP -p 90
ssh root@YOUR_SERVER_IP -p 143
```

## 🔧 Konfigurasi Lanjutan

### Cek Status Layanan

```bash
# Status OpenSSH
systemctl status ssh

# Status Dropbear
systemctl status dropbear

# Cek port yang digunakan
netstat -tlnp | grep -E "(sshd|dropbear)"
```

### Restart Layanan

```bash
# Restart OpenSSH
sudo systemctl restart ssh

# Restart Dropbear
sudo systemctl restart dropbear
```

### Uninstall

Untuk mengembalikan konfigurasi ke pengaturan sebelumnya:

```bash
sudo /root/uninstall-tunnel.sh
```

## 📁 File Konfigurasi

### OpenSSH
- **Config**: `/etc/ssh/sshd_config`
- **Backup**: `/etc/ssh/sshd_config.backup.TIMESTAMP`

### Dropbear
- **Config**: `/etc/default/dropbear`
- **Backup**: `/etc/default/dropbear.backup.TIMESTAMP`
- **Host Keys**: `/etc/dropbear/`

## 🔍 Troubleshooting

### Port Already in Use

Script otomatis menangani port conflict dengan:
1. Deteksi port yang sudah digunakan
2. Skip port yang tidak tersedia
3. Gunakan port alternatif jika diperlukan

### Service Tidak Start

```bash
# Cek log error
journalctl -u ssh -f
journalctl -u dropbear -f

# Cek konfigurasi
sudo sshd -t  # Test SSH config
```

### Firewall Issues

```bash
# Cek status UFW
sudo ufw status

# Allow port manual jika diperlukan
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 🛡️ Keamanan

### Default Security Settings

- **Root Login**: Enabled (dapat diubah sesuai kebutuhan)
- **Password Auth**: Enabled
- **Key Auth**: Enabled
- **Empty Passwords**: Disabled
- **Connection Limits**: MaxSessions 10, MaxAuthTries 3

### Rekomendasi Keamanan

1. **Ganti Password Root**:
   ```bash
   passwd root
   ```

2. **Setup SSH Key Authentication**:
   ```bash
   ssh-keygen -t rsa -b 4096
   ssh-copy-id root@your-server-ip
   ```

3. **Disable Password Auth** (setelah setup SSH key):
   Edit `/etc/ssh/sshd_config`:
   ```
   PasswordAuthentication no
   ```

4. **Enable Fail2Ban**:
   ```bash
   apt install fail2ban
   systemctl enable fail2ban
   ```

## 📊 Monitoring

### Cek Koneksi Aktif

```bash
# Koneksi SSH aktif
ss -tuln | grep -E ":(22|80|443|444|90|143)"

# User yang sedang login
who
w
```

### Log Monitoring

```bash
# SSH login attempts
tail -f /var/log/auth.log

# Dropbear logs
journalctl -u dropbear -f
```

## ⚡ Performance Tuning

### Optimasi Koneksi

Edit `/etc/ssh/sshd_config`:
```
# Faster connection
UseDNS no
GSSAPIAuthentication no

# Connection keep-alive
ClientAliveInterval 60
ClientAliveCountMax 3
```

### Optimasi Dropbear

Edit `/etc/default/dropbear`:
```
# Increase receive window
DROPBEAR_RECEIVE_WINDOW=65536

# Disable slow features
DROPBEAR_EXTRA_ARGS="$DROPBEAR_EXTRA_ARGS -w"
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - lihat file LICENSE untuk detail lengkap.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)

## 📝 Changelog

### v1.0.0
- Initial release
- Support Debian 11/12 dan Ubuntu 22/24
- Auto port conflict detection
- OpenSSH dan Dropbear configuration
- Backup dan restore functionality
- UFW firewall integration

---

**⚠️ Disclaimer**: Script ini dibuat untuk keperluan tunneling yang legitimate. Pastikan Anda mematuhi terms of service provider VPS dan hukum yang berlaku di wilayah Anda.