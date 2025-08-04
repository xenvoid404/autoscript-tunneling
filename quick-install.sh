#!/bin/bash

# Quick WebSocket SSH Installer
# One-command installation for HTTP Injector WebSocket SSH

echo "🚀 WebSocket SSH Quick Installer untuk HTTP Injector"
echo "=================================================="

# Update and install packages
echo "📦 Installing packages..."
sudo apt update -y && sudo apt install -y openssh-server dropbear-bin curl

# Download ws-epro
echo "⬇️  Downloading ws-epro..."
sudo curl -sL -o /usr/local/bin/ws-epro https://raw.githubusercontent.com/essoojay/PROXY-SSH-OVER-CDN/master/ws-epro/ws-epro
sudo chmod +x /usr/local/bin/ws-epro

# Create config
echo "⚙️  Creating configuration..."
sudo mkdir -p /etc/ws-epro
sudo tee /etc/ws-epro/config.yml > /dev/null <<EOF
verbose: 1
listen:
  - target_host: 127.0.0.1
    target_port: 22
    listen_port: 8080
  - target_host: 127.0.0.1
    target_port: 2222
    listen_port: 8081
EOF

# Create startup script
echo "🔧 Creating startup script..."
tee ~/start-ws-ssh.sh > /dev/null <<'EOF'
#!/bin/bash
sudo pkill sshd dropbear ws-epro 2>/dev/null
sudo /usr/sbin/sshd -p 22
sudo dropbear -p 2222 -F &
sleep 2
/usr/local/bin/ws-epro -f /etc/ws-epro/config.yml &
sleep 3
echo "✅ Services started!"
echo "🌐 WebSocket URLs:"
echo "   SSH: ws://$(curl -s ifconfig.me):8080"
echo "   Dropbear: ws://$(curl -s ifconfig.me):8081"
EOF
chmod +x ~/start-ws-ssh.sh

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw allow 22,2222,8080,8081/tcp 2>/dev/null || echo "UFW not available"

echo ""
echo "✅ Installation Complete!"
echo "🚀 Start services: ~/start-ws-ssh.sh"
echo "🌐 WebSocket URLs for HTTP Injector:"
echo "   - OpenSSH:  ws://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):8080"
echo "   - Dropbear: ws://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):8081"
echo ""

# Auto-start
read -p "Start services now? (y/n): " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] && ~/start-ws-ssh.sh