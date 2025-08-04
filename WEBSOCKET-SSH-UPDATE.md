# Update: WebSocket SSH untuk HTTP Injector

## Perubahan pada install.sh

Script `install.sh` telah diupdate untuk mendukung instalasi WebSocket SSH yang dapat digunakan dengan HTTP Injector.

### Fitur Baru

1. **Menu Pilihan Instalasi:**
   - Standard Tunneling (SSH + Dropbear)
   - WebSocket SSH untuk HTTP Injector  
   - Install keduanya (Standard + WebSocket)

2. **Command Line Options:**
   ```bash
   bash install.sh --websocket    # Install WebSocket SSH only
   bash install.sh --standard     # Install Standard Tunneling only
   bash install.sh --both         # Install both modes
   bash install.sh --help         # Show help
   ```

3. **Interactive Mode:**
   - Menjalankan `bash install.sh` tanpa parameter akan menampilkan menu pilihan

## Instalasi WebSocket SSH

### One-Command Install
```bash
sudo bash install.sh --websocket
```

### Komponen yang Diinstall
- OpenSSH Server (port 22)
- Dropbear SSH (port 2222)
- ws-epro WebSocket proxy
- Systemd service untuk auto-start
- Startup script di `/root/start-websocket-ssh.sh`

### Port Mapping
| Service | Local Port | WebSocket Port |
|---------|------------|----------------|
| OpenSSH | 22 | 8080 |
| Dropbear | 2222 | 8081 |

## Penggunaan

### Menjalankan Services
```bash
/root/start-websocket-ssh.sh
```

### Konfigurasi HTTP Injector
1. Buka HTTP Injector
2. Pilih Custom SSH
3. Set Connection Type: WebSocket
4. Masukkan:
   - **Host:** IP_SERVER_ANDA
   - **Port:** 8080 (untuk OpenSSH) atau 8081 (untuk Dropbear)
   - **Protocol:** WebSocket (ws://)

### WebSocket URLs
- SSH (OpenSSH): `ws://YOUR_SERVER_IP:8080`
- SSH (Dropbear): `ws://YOUR_SERVER_IP:8081`

## File yang Dibuat

- `/usr/local/bin/ws-epro` - WebSocket proxy binary
- `/etc/ws-epro/config.yml` - Konfigurasi ws-epro
- `/etc/systemd/system/ws-epro.service` - Systemd service
- `/root/start-websocket-ssh.sh` - Startup script

## Troubleshooting

### Restart Services
```bash
/root/start-websocket-ssh.sh
```

### Check Status
```bash
ps aux | grep -E "(sshd|dropbear|ws-epro)"
```

### Test WebSocket
```bash
curl -I http://localhost:8080  # Test OpenSSH WebSocket
curl -I http://localhost:8081  # Test Dropbear WebSocket
```

## Kompatibilitas

- Debian 11/12
- Ubuntu 20/22/24
- Requires root access
- Membutuhkan koneksi internet untuk download ws-epro

---

**Catatan:** Update ini tidak mengubah fungsionalitas standard tunneling yang sudah ada. Semua fitur lama tetap berfungsi normal.