#!/bin/bash

# Test script for Modern Tunneling Autoscript v3.0.0
# Verifies installation and basic functionality

set -e

echo "Testing Modern Tunneling Autoscript v3.0.0"
echo "=========================================="

# Test 1: Check if installation directories exist
echo "1. Checking installation directories..."
directories=(
    "/opt/autoscript"
    "/etc/autoscript"
    "/etc/xray"
    "/var/log/autoscript"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  ✓ $dir exists"
    else
        echo "  ✗ $dir missing"
        exit 1
    fi
done

# Test 2: Check if configuration files exist
echo ""
echo "2. Checking configuration files..."
config_files=(
    "/opt/autoscript/config/vmess.json"
    "/opt/autoscript/config/vless.json"
    "/opt/autoscript/config/trojan.json"
    "/opt/autoscript/config/nginx.conf"
    "/etc/xray/vmess.json"
    "/etc/xray/vless.json"
    "/etc/xray/trojan.json"
)

for file in "${config_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        exit 1
    fi
done

# Test 3: Check if systemd service files exist
echo ""
echo "3. Checking systemd service files..."
service_files=(
    "/etc/systemd/system/xray-vmess.service"
    "/etc/systemd/system/xray-vless.service"
    "/etc/systemd/system/xray-trojan.service"
)

for file in "${service_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        exit 1
    fi
done

# Test 4: Check if management commands exist
echo ""
echo "4. Checking management commands..."
commands=(
    "/usr/local/bin/autoscript-mgmt"
    "/usr/local/bin/xray-mgmt"
    "/usr/local/bin/xray-client"
)

for cmd in "${commands[@]}"; do
    if [[ -x "$cmd" ]]; then
        echo "  ✓ $cmd exists and is executable"
    else
        echo "  ✗ $cmd missing or not executable"
        exit 1
    fi
done

# Test 5: Check if required utilities exist
echo ""
echo "5. Checking required utilities..."
utilities=(
    "xray"
    "nginx"
    "jq"
    "openssl"
)

for util in "${utilities[@]}"; do
    if command -v "$util" >/dev/null 2>&1; then
        echo "  ✓ $util is installed"
    else
        echo "  ✗ $util is missing"
        exit 1
    fi
done

# Test 6: Validate JSON configurations
echo ""
echo "6. Validating JSON configurations..."
json_files=(
    "/etc/xray/vmess.json"
    "/etc/xray/vless.json"
    "/etc/xray/trojan.json"
)

for file in "${json_files[@]}"; do
    if jq . "$file" >/dev/null 2>&1; then
        echo "  ✓ $file is valid JSON"
    else
        echo "  ✗ $file has invalid JSON syntax"
        exit 1
    fi
done

# Test 7: Check if services are enabled
echo ""
echo "7. Checking if services are enabled..."
services=(
    "xray-vmess"
    "xray-vless"
    "xray-trojan"
    "nginx"
)

for service in "${services[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "  ✓ $service is enabled"
    else
        echo "  ✗ $service is not enabled"
        exit 1
    fi
done

# Test 8: Test Xray configurations
echo ""
echo "8. Testing Xray configurations..."
for file in "${json_files[@]}"; do
    if xray run -test -config "$file" >/dev/null 2>&1; then
        echo "  ✓ $(basename "$file") configuration is valid"
    else
        echo "  ✗ $(basename "$file") configuration is invalid"
        exit 1
    fi
done

# Test 9: Test Nginx configuration
echo ""
echo "9. Testing Nginx configuration..."
if nginx -t >/dev/null 2>&1; then
    echo "  ✓ Nginx configuration is valid"
else
    echo "  ✗ Nginx configuration is invalid"
    exit 1
fi

# Test 10: Check SSL certificates
echo ""
echo "10. Checking SSL certificates..."
cert_files=(
    "/etc/xray/xray.crt"
    "/etc/xray/xray.key"
)

for file in "${cert_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        exit 1
    fi
done

# Test certificate validity
if openssl x509 -in /etc/xray/xray.crt -noout -text >/dev/null 2>&1; then
    echo "  ✓ SSL certificate is valid"
else
    echo "  ✗ SSL certificate is invalid"
    exit 1
fi

# Test 11: Check port availability
echo ""
echo "11. Checking if required ports are available..."
required_ports=(22 80 443 55 58 1054 1055 1057 1058 1059 1060 1061 8443)

for port in "${required_ports[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        echo "  ✓ Port $port is in use (expected)"
    else
        echo "  ! Port $port is not in use (may be normal if services not started)"
    fi
done

echo ""
echo "=========================================="
echo "All tests passed! Installation appears to be successful."
echo ""
echo "Next steps:"
echo "1. Start services: autoscript-mgmt start"
echo "2. Check status: autoscript-mgmt status"
echo "3. Add clients: xray-client add vmess username"
echo "4. List clients: xray-client list"
echo ""
echo "For more information, see the README.md file."