#!/bin/bash

# Script untuk menjalankan SSH, Dropbear, dan ws-epro WebSocket Proxy
# Untuk HTTP Injector dengan WebSocket

echo "Starting SSH and Dropbear services..."

# Stop existing processes
sudo pkill sshd 2>/dev/null
sudo pkill dropbear 2>/dev/null
sudo pkill ws-epro 2>/dev/null

# Start SSH on port 22
echo "Starting OpenSSH on port 22..."
sudo /usr/sbin/sshd -p 22

# Start Dropbear on port 2222
echo "Starting Dropbear on port 2222..."
sudo dropbear -p 2222 -F &

# Wait a moment for services to start
sleep 2

# Start ws-epro WebSocket proxy
echo "Starting ws-epro WebSocket proxy..."
/usr/local/bin/ws-epro -f /etc/ws-epro/tunws.conf &

# Wait and verify services
sleep 3

echo ""
echo "Service Status:"
echo "==============="

# Check SSH
if pgrep sshd > /dev/null; then
    echo "✓ OpenSSH is running on port 22"
else
    echo "✗ OpenSSH failed to start"
fi

# Check Dropbear
if pgrep dropbear > /dev/null; then
    echo "✓ Dropbear is running on port 2222"
else
    echo "✗ Dropbear failed to start"
fi

# Check ws-epro
if pgrep ws-epro > /dev/null; then
    echo "✓ ws-epro WebSocket proxy is running"
    echo "  - SSH WebSocket: ws://YOUR_SERVER_IP:8080"
    echo "  - Dropbear WebSocket: ws://YOUR_SERVER_IP:8081"
else
    echo "✗ ws-epro failed to start"
fi

echo ""
echo "Configuration for HTTP Injector:"
echo "================================"
echo "1. SSH via WebSocket: ws://YOUR_SERVER_IP:8080"
echo "2. Dropbear via WebSocket: ws://YOUR_SERVER_IP:8081"
echo ""
echo "Replace YOUR_SERVER_IP with your actual server IP address"