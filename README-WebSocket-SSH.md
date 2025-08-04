# Konfigurasi WebSocket SSH untuk HTTP Injector

Dokumentasi ini menjelaskan bagaimana mengkonfigurasi OpenSSH dan Dropbear agar dapat digunakan melalui aplikasi HTTP Injector menggunakan WebSocket dengan `ws-epro` sebagai proxy.

## Komponen yang Terinstall

1. **OpenSSH Server** - SSH daemon standar (port 22)
2. **Dropbear** - SSH server ringan (port 2222)  
3. **ws-epro** - WebSocket proxy untuk tunneling SSH

## File Konfigurasi

### ws-epro Configuration (`/etc/ws-epro/config.yml`)
```yaml
# verbose level 0=info, 1=verbose, 2=very verbose
verbose: 1
listen:
  # openssh
  - target_host: 127.0.0.1
    target_port: 22
    listen_port: 8080

  # dropbear  
  - target_host: 127.0.0.1
    target_port: 2222
    listen_port: 8081
```

### Systemd Service (`/etc/systemd/system/ws-epro.service`)
```ini
[Unit]
Description=WebSocket to SSH/Dropbear Proxy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Port Mapping

| Service | Local Port | WebSocket Port | URL |
|---------|------------|----------------|-----|
| OpenSSH | 22 | 8080 | `ws://YOUR_SERVER_IP:8080` |
| Dropbear | 2222 | 8081 | `ws://YOUR_SERVER_IP:8081` |

## Cara Menjalankan

### Manual Start
```bash
# Jalankan script startup
./start-ws-epro.sh
```

### Systemd (jika tersedia)
```bash
sudo systemctl enable ws-epro
sudo systemctl start ws-epro
sudo systemctl start ssh
```

### Manual Commands
```bash
# Start SSH
sudo /usr/sbin/sshd -p 22

# Start Dropbear  
sudo dropbear -p 2222 -F &

# Start ws-epro
/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml &
```

## Konfigurasi HTTP Injector

1. **Buka HTTP Injector**
2. **Pilih Custom SSH**
3. **Set Connection Type: WebSocket**
4. **Masukkan konfigurasi:**

### Untuk OpenSSH:
- **Host:** `YOUR_SERVER_IP`
- **Port:** `8080`
- **Protocol:** `WebSocket (ws://)`
- **Path:** `/` (default)

### Untuk Dropbear:
- **Host:** `YOUR_SERVER_IP`  
- **Port:** `8081`
- **Protocol:** `WebSocket (ws://)`
- **Path:** `/` (default)

## Verifikasi Koneksi

```bash
# Test WebSocket SSH proxy
curl -I http://localhost:8080
# Should return: HTTP/1.1 101 Switching Protocols

# Test WebSocket Dropbear proxy  
curl -I http://localhost:8081
# Should return: HTTP/1.1 101 Switching Protocols

# Check running processes
ps aux | grep -E "(sshd|dropbear|ws-epro)"
```

## Troubleshooting

### Service tidak berjalan
```bash
# Check logs
journalctl -u ws-epro -f

# Manual restart
sudo pkill ws-epro
/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml
```

### Port sudah digunakan
```bash
# Check port usage
netstat -tlnp | grep -E ":8080|:8081|:22|:2222"

# Kill conflicting processes
sudo pkill -f "port 8080"
```

### Permission denied
```bash
# Fix permissions
sudo chmod +x /usr/local/bin/ws-epro
sudo chown root:root /etc/ws-epro/config.yml
```

## Security Notes

1. **Firewall:** Pastikan port 8080 dan 8081 terbuka di firewall
2. **SSH Keys:** Gunakan SSH key authentication untuk keamanan
3. **User Access:** Buat user khusus untuk SSH access
4. **Monitoring:** Monitor log untuk aktivitas mencurigakan

## File Locations

- **ws-epro binary:** `/usr/local/bin/ws-epro`
- **Configuration:** `/etc/ws-epro/config.yml`
- **Systemd service:** `/etc/systemd/system/ws-epro.service`
- **Startup script:** `./start-ws-epro.sh`

---

**Catatan:** Ganti `YOUR_SERVER_IP` dengan IP address server Anda yang sebenarnya.