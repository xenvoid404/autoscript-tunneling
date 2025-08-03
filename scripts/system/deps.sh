#!/bin/bash

# Dependencies installer for Modern Tunneling Autoscript
# Handles installation of all required and optional packages

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/config/system.conf"

# Function to update package repository
update_package_repository() {
    print_section "Updating Package Repository"
    
    # Update package lists
    if apt-get update &>/dev/null; then
        print_success "Package repository updated successfully"
    else
        print_error "Failed to update package repository"
        return 1
    fi
    
    return 0
}

# Function to install required packages
install_required_packages() {
    print_section "Installing Required Packages"
    
    local failed_packages=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        print_info "Installing package: $package"
        
        if apt-get install -y "$package" &>/dev/null; then
            print_success "Installed: $package"
        else
            print_error "Failed to install: $package"
            failed_packages+=("$package")
        fi
    done
    
    # Check if any required packages failed
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_error "Failed to install required packages: ${failed_packages[*]}"
        return 1
    fi
    
    print_success "All required packages installed successfully"
    return 0
}

# Function to install optional packages
install_optional_packages() {
    print_section "Installing Optional Packages"
    
    local failed_packages=()
    
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        print_info "Installing optional package: $package"
        
        if apt-get install -y "$package" &>/dev/null; then
            print_success "Installed: $package"
        else
            print_warning "Failed to install optional package: $package"
            failed_packages+=("$package")
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_warning "Some optional packages failed to install: ${failed_packages[*]}"
    fi
    
    return 0
}

# Function to install development tools
install_development_tools() {
    print_section "Installing Development Tools"
    
    local dev_packages=(
        "build-essential"
        "cmake"
        "git"
        "pkg-config"
        "libssl-dev"
        "zlib1g-dev"
        "libbz2-dev"
        "libreadline-dev"
        "libsqlite3-dev"
        "libncurses5-dev"
        "libncursesw5-dev"
        "xz-utils"
        "tk-dev"
        "libffi-dev"
        "liblzma-dev"
    )
    
    for package in "${dev_packages[@]}"; do
        if apt-get install -y "$package" &>/dev/null; then
            print_success "Installed dev tool: $package"
        else
            print_warning "Failed to install dev tool: $package"
        fi
    done
    
    return 0
}

# Function to install specific version of Xray-core
install_xray_core() {
    if [[ "$ENABLE_XRAY" != "true" ]]; then
        print_info "Xray installation skipped (disabled in config)"
        return 0
    fi
    
    print_section "Installing Xray-core"
    
    # Create Xray directories
    create_directory "$XRAY_CONFIG_PATH" "755"
    create_directory "$XRAY_LOG_PATH" "755"
    
    # Detect system architecture
    local arch
    case $(uname -m) in
        x86_64)  arch="linux-64" ;;
        aarch64) arch="linux-arm64-v8a" ;;
        armv7l)  arch="linux-arm32-v7a" ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    # Download and install Xray
    local xray_url="${XRAY_DOWNLOAD_URL}/Xray-${arch}.zip"
    local temp_dir="/tmp/xray_install"
    
    create_directory "$temp_dir" "755"
    
    print_info "Downloading Xray-core for $arch..."
    if download_file "$xray_url" "$temp_dir/xray.zip"; then
        cd "$temp_dir" || return 1
        
        if unzip -q xray.zip; then
            # Install Xray binary
            if cp xray /usr/local/bin/; then
                chmod +x /usr/local/bin/xray
                print_success "Xray binary installed successfully"
            else
                print_error "Failed to install Xray binary"
                return 1
            fi
            
            # Install geoip and geosite files
            for file in geoip.dat geosite.dat; do
                if [[ -f "$file" ]]; then
                    cp "$file" "$XRAY_CONFIG_PATH/"
                    print_info "Installed $file"
                fi
            done
        else
            print_error "Failed to extract Xray archive"
            return 1
        fi
    else
        print_error "Failed to download Xray-core"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    if command_exists xray; then
        local xray_version=$(xray version | head -n1)
        print_success "Xray-core installed: $xray_version"
    else
        print_error "Xray installation verification failed"
        return 1
    fi
    
    return 0
}

# Function to install Dropbear SSH
install_dropbear() {
    if [[ "$ENABLE_DROPBEAR" != "true" ]]; then
        print_info "Dropbear installation skipped (disabled in config)"
        return 0
    fi
    
    print_section "Installing Dropbear SSH"
    
    # Install Dropbear from repository
    if install_package "dropbear"; then
        # Stop the service initially
        systemctl stop dropbear &>/dev/null
        systemctl disable dropbear &>/dev/null
        
        print_success "Dropbear installed successfully"
    else
        print_error "Failed to install Dropbear"
        return 1
    fi
    
    return 0
}

# Function to configure package auto-removal
configure_auto_removal() {
    print_section "Configuring Automatic Package Cleanup"
    
    # Remove unnecessary packages
    if apt-get autoremove -y &>/dev/null; then
        print_success "Unnecessary packages removed"
    fi
    
    # Clean package cache
    if apt-get autoclean &>/dev/null; then
        print_success "Package cache cleaned"
    fi
    
    # Configure automatic updates (optional)
    if command_exists unattended-upgrades; then
        print_info "Configuring automatic security updates"
        
        cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
        
        print_success "Automatic security updates configured"
    fi
    
    return 0
}

# Function to verify all installations
verify_installations() {
    print_section "Verifying Installations"
    
    local verification_failed=false
    
    # Check required commands
    local required_commands=(
        "curl"
        "wget"
        "unzip"
        "tar"
        "gzip"
        "jq"
        "bc"
        "uuidgen"
        "netstat"
        "lsof"
    )
    
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            print_success "✓ $cmd is available"
        else
            print_error "✗ $cmd is not available"
            verification_failed=true
        fi
    done
    
    # Check optional commands
    local optional_commands=("ufw" "fail2ban-client" "screen" "tmux")
    
    for cmd in "${optional_commands[@]}"; do
        if command_exists "$cmd"; then
            print_info "✓ $cmd is available (optional)"
        else
            print_warning "✗ $cmd is not available (optional)"
        fi
    done
    
    # Check Xray if enabled
    if [[ "$ENABLE_XRAY" == "true" ]]; then
        if command_exists xray; then
            print_success "✓ Xray-core is installed"
        else
            print_error "✗ Xray-core is not installed"
            verification_failed=true
        fi
    fi
    
    # Check Dropbear if enabled
    if [[ "$ENABLE_DROPBEAR" == "true" ]]; then
        if command_exists dropbear; then
            print_success "✓ Dropbear is installed"
        else
            print_error "✗ Dropbear is not installed"
            verification_failed=true
        fi
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        print_error "Some installations failed verification"
        return 1
    else
        print_success "All installations verified successfully"
        return 0
    fi
}

# Main installation function
main() {
    # Check if running as root
    check_root
    
    # Check system compatibility
    check_compatibility
    
    # Check internet connectivity
    if ! check_internet; then
        print_error "Internet connectivity required for installation"
        exit 1
    fi
    
    print_banner
    print_section "Dependencies Installation"
    
    # Update package repository
    if ! update_package_repository; then
        print_error "Failed to update package repository"
        exit 1
    fi
    
    # Install required packages
    if ! install_required_packages; then
        print_error "Failed to install required packages"
        exit 1
    fi
    
    # Install optional packages
    install_optional_packages
    
    # Install development tools
    install_development_tools
    
    # Install Xray-core
    if ! install_xray_core; then
        print_error "Xray-core installation failed"
    fi
    
    # Install Dropbear
    if ! install_dropbear; then
        print_error "Dropbear installation failed"
    fi
    
    # Configure auto-removal
    configure_auto_removal
    
    # Verify installations
    if ! verify_installations; then
        print_error "Installation verification failed"
        exit 1
    fi
    
    print_success "Dependencies installation completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi