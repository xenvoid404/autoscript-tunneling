#!/bin/bash

# Fix for autoscript installation hanging on apt-get upgrade
# This script provides solutions to resolve the hanging issue

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  Autoscript Installation Hang Fix Script${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Kill any hanging processes
kill_hanging_processes() {
    print_info "Checking for hanging apt/dpkg processes..."
    
    # Find and kill apt/dpkg processes
    pkill -f "apt-get"
    pkill -f "dpkg"
    pkill -f "unattended-upgrade"
    
    # Wait a moment
    sleep 2
    
    # Check if any processes are still running
    if pgrep -f "apt-get\|dpkg\|unattended-upgrade" > /dev/null; then
        print_warning "Some processes are still running. Trying force kill..."
        pkill -9 -f "apt-get"
        pkill -9 -f "dpkg"
        pkill -9 -f "unattended-upgrade"
        sleep 2
    fi
    
    print_success "Process cleanup completed"
}

# Remove lock files
remove_lock_files() {
    print_info "Removing package manager lock files..."
    
    rm -f /var/lib/dpkg/lock
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/apt/lists/lock
    
    print_success "Lock files removed"
}

# Configure package manager for non-interactive mode
configure_noninteractive() {
    print_info "Configuring non-interactive package management..."
    
    # Set environment variables
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
    
    # Create debconf configuration
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    
    print_success "Non-interactive mode configured"
}

# Fix broken packages
fix_broken_packages() {
    print_info "Fixing any broken packages..."
    
    dpkg --configure -a
    apt-get install -f -y
    
    print_success "Package fix completed"
}

# Update package lists
update_packages() {
    print_info "Updating package lists..."
    
    apt-get clean
    apt-get update
    
    print_success "Package lists updated"
}

# Safe upgrade with timeouts and non-interactive flags
safe_upgrade() {
    print_info "Performing safe system upgrade..."
    
    # Use timeout and non-interactive flags
    timeout 300 apt-get upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confnew" \
        -o APT::Get::Assume-Yes=true \
        -o APT::Get::Fix-Broken=true \
        -o APT::Get::Force-Yes=true
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "System upgrade completed successfully"
    elif [ $exit_code -eq 124 ]; then
        print_warning "Upgrade timed out after 5 minutes"
        print_info "You may need to run 'apt-get upgrade -y' manually later"
    else
        print_error "Upgrade failed with exit code: $exit_code"
        return 1
    fi
}

# Modified autoscript installation
install_autoscript_fixed() {
    print_info "Installing autoscript with fixed settings..."
    
    # Set environment for non-interactive installation
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
    
    # Download and run with timeout
    timeout 1800 bash -c '
        wget -O - https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/quick-install.sh | bash
    '
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Autoscript installation completed successfully"
    elif [ $exit_code -eq 124 ]; then
        print_error "Installation timed out after 30 minutes"
        print_info "Try running the installation manually with non-interactive flags"
    else
        print_error "Installation failed with exit code: $exit_code"
    fi
}

# Alternative manual installation
manual_installation() {
    print_info "Starting manual autoscript installation..."
    
    # Create temp directory
    mkdir -p /tmp/autoscript-install
    cd /tmp/autoscript-install
    
    # Download scripts
    wget -O quick-install.sh https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/quick-install.sh
    wget -O install.sh https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/install.sh
    
    # Make executable
    chmod +x quick-install.sh install.sh
    
    # Set non-interactive environment
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
    
    print_info "Running installation with modified environment..."
    
    # Run installation
    bash install.sh
    
    # Cleanup
    cd /
    rm -rf /tmp/autoscript-install
}

# Main menu
show_menu() {
    clear
    print_header
    
    echo "Choose an option:"
    echo "1. Quick Fix (Kill processes + Remove locks + Try installation)"
    echo "2. Complete Fix (Full cleanup + Non-interactive setup + Installation)"
    echo "3. Manual Installation (Download and run manually)"
    echo "4. System Cleanup Only (Fix packages without installation)"
    echo "5. Exit"
    echo ""
    read -p "Select option [1-5]: " choice
    
    case $choice in
        1)
            kill_hanging_processes
            remove_lock_files
            configure_noninteractive
            install_autoscript_fixed
            ;;
        2)
            kill_hanging_processes
            remove_lock_files
            configure_noninteractive
            fix_broken_packages
            update_packages
            safe_upgrade
            install_autoscript_fixed
            ;;
        3)
            configure_noninteractive
            manual_installation
            ;;
        4)
            kill_hanging_processes
            remove_lock_files
            fix_broken_packages
            update_packages
            safe_upgrade
            ;;
        5)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option. Please try again."
            sleep 2
            show_menu
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    print_info "Please run: sudo bash $0"
    exit 1
fi

# Show menu
show_menu

print_info "Fix script completed. Check the output above for any issues."