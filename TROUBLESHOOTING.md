# Autoscript Installation Hang - Troubleshooting Guide

## Problem Description
The autoscript installation gets stuck at the "apt-get upgrade -y" step and doesn't progress further.

## Common Causes
1. **Interactive prompts**: Package upgrades may require user input for configuration
2. **Lock files**: Other package managers or update processes are running
3. **Needrestart service**: Service restart prompts during upgrades
4. **Unattended upgrades**: Automatic updates running in background
5. **Broken packages**: Existing package conflicts

## Quick Solutions

### Solution 1: Kill Process and Use Non-Interactive Mode
```bash
# Kill any hanging processes
sudo pkill -f "apt-get"
sudo pkill -f "dpkg"

# Remove lock files
sudo rm -f /var/lib/dpkg/lock*
sudo rm -f /var/cache/apt/archives/lock

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Try installation again
wget -O - https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/quick-install.sh | sudo bash
```

### Solution 2: Manual Step-by-Step Installation
```bash
# 1. Update packages with timeout and non-interactive flags
sudo timeout 300 apt-get update
sudo timeout 300 apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

# 2. Download and run autoscript
wget -O autoscript.sh https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh
chmod +x autoscript.sh
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash autoscript.sh
```

### Solution 3: Use the Fix Script
Use the provided fix script that handles all common issues:

```bash
# Download and run the fix script
wget -O fix_autoscript_hang.sh https://raw.githubusercontent.com/path/to/fix_autoscript_hang.sh
chmod +x fix_autoscript_hang.sh
sudo bash fix_autoscript_hang.sh
```

## Detailed Troubleshooting Steps

### Step 1: Check for Running Processes
```bash
# Check for apt/dpkg processes
ps aux | grep -E "(apt|dpkg)" | grep -v grep

# Check for unattended upgrades
ps aux | grep unattended-upgrade
```

### Step 2: Remove Lock Files
```bash
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/apt/lists/lock
```

### Step 3: Fix Broken Packages
```bash
sudo dpkg --configure -a
sudo apt-get install -f -y
```

### Step 4: Configure Non-Interactive Mode
```bash
# Set environment variables
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Configure debconf
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
```

### Step 5: Safe Upgrade with Timeout
```bash
sudo timeout 300 apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confnew"
```

## Prevention Tips

1. **Always use non-interactive mode** for automated scripts:
   ```bash
   export DEBIAN_FRONTEND=noninteractive
   ```

2. **Use timeouts** for package operations:
   ```bash
   timeout 300 apt-get upgrade -y
   ```

3. **Handle configuration conflicts**:
   ```bash
   apt-get upgrade -y -o Dpkg::Options::="--force-confold"
   ```

4. **Disable service restart prompts**:
   ```bash
   export NEEDRESTART_MODE=a
   ```

## Alternative Installation Methods

### Method 1: Skip System Update
If the system is already up to date, you can try downloading the install script directly and modify it to skip the upgrade step.

### Method 2: Use Docker/Container
Run the installation in a clean container environment to avoid host system conflicts.

### Method 3: Manual Service Installation
Install each service component manually instead of using the automated script.

## Getting Help

If none of these solutions work:

1. Check the system logs: `sudo journalctl -xe`
2. Check apt logs: `sudo tail -f /var/log/apt/history.log`
3. Try on a fresh VPS/server
4. Contact the script maintainer with specific error details

## Common Error Messages and Fixes

| Error | Solution |
|-------|----------|
| `Could not get lock /var/lib/dpkg/lock` | Remove lock files and kill processes |
| `Package operation timeout` | Use shorter timeout or non-interactive mode |
| `Configuration file prompts` | Use force-confold/confdef options |
| `Service restart required` | Set NEEDRESTART_MODE=a |
| `Broken packages` | Run `dpkg --configure -a` and `apt install -f` |