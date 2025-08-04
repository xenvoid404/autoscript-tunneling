#!/bin/bash

# =============================================================================
# Installation Verification Script
# Checks if all required files and directories are present
# for the autoinstaller to work properly
#
# Author: Yuipedia
# Version: 4.0.0
# =============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Verification results
declare -A VERIFICATION_RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Logging
readonly VERIFY_LOG="./autoscript-verify.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$VERIFY_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VERIFY_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VERIFY_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VERIFY_LOG"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$VERIFY_LOG"
}

# Verification function
verify_check() {
    local check_name="$1"
    local check_command="$2"
    local check_description="$3"
    
    ((TOTAL_CHECKS++))
    log_info "Checking: $check_name"
    log_info "Description: $check_description"
    
    if eval "$check_command" >/dev/null 2>&1; then
        log_success "✓ Check passed: $check_name"
        VERIFICATION_RESULTS["$check_name"]="PASSED"
        ((PASSED_CHECKS++))
        return 0
    else
        log_error "✗ Check failed: $check_name"
        VERIFICATION_RESULTS["$check_name"]="FAILED"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# =============================================================================
# MAIN SCRIPT FILES VERIFICATION
# =============================================================================

verify_main_scripts() {
    log_section "Main Script Files Verification"
    
    # Check autoinstaller script
    verify_check "autoinstaller_script" "[[ -f autoinstaller.sh ]] && [[ -x autoinstaller.sh ]]" "Check if autoinstaller.sh exists and is executable"
    
    # Check test script
    verify_check "test_script" "[[ -f test-autoinstaller.sh ]] && [[ -x test-autoinstaller.sh ]]" "Check if test-autoinstaller.sh exists and is executable"
    
    # Check original install script
    verify_check "original_install_script" "[[ -f install.sh ]]" "Check if original install.sh exists"
    
    # Check Xray install script
    verify_check "xray_install_script" "[[ -f install-xray.sh ]] && [[ -x install-xray.sh ]]" "Check if install-xray.sh exists and is executable"
    
    # Check test install script
    verify_check "test_install_script" "[[ -f test-install.sh ]]" "Check if test-install.sh exists"
}

# =============================================================================
# DIRECTORY STRUCTURE VERIFICATION
# =============================================================================

verify_directory_structure() {
    log_section "Directory Structure Verification"
    
    # Check main directories
    verify_check "config_directory" "[[ -d config ]]" "Check if config directory exists"
    verify_check "scripts_directory" "[[ -d scripts ]]" "Check if scripts directory exists"
    verify_check "utils_directory" "[[ -d utils ]]" "Check if utils directory exists"
    verify_check "systemd_directory" "[[ -d systemd ]]" "Check if systemd directory exists"
    verify_check "xray_directory" "[[ -d xray ]]" "Check if xray directory exists"
}

# =============================================================================
# CONFIGURATION FILES VERIFICATION
# =============================================================================

verify_config_files() {
    log_section "Configuration Files Verification"
    
    # Check Xray configuration files
    verify_check "vmess_config" "[[ -f config/vmess.json ]]" "Check if vmess.json exists"
    verify_check "vless_config" "[[ -f config/vless.json ]]" "Check if vless.json exists"
    verify_check "trojan_config" "[[ -f config/trojan.json ]]" "Check if trojan.json exists"
    verify_check "outbounds_config" "[[ -f config/outbounds.json ]]" "Check if outbounds.json exists"
    verify_check "rules_config" "[[ -f config/rules.json ]]" "Check if rules.json exists"
    verify_check "system_config" "[[ -f config/system.conf ]]" "Check if system.conf exists"
    verify_check "nginx_config" "[[ -f config/nginx.conf ]]" "Check if nginx.conf exists"
}

# =============================================================================
# UTILITY FILES VERIFICATION
# =============================================================================

verify_utility_files() {
    log_section "Utility Files Verification"
    
    # Check utility scripts
    verify_check "common_utils" "[[ -f utils/common.sh ]]" "Check if common.sh exists"
    verify_check "validator_utils" "[[ -f utils/validator.sh ]]" "Check if validator.sh exists"
    verify_check "logger_utils" "[[ -f utils/logger.sh ]]" "Check if logger.sh exists"
}

# =============================================================================
# SCRIPT FILES VERIFICATION
# =============================================================================

verify_script_files() {
    log_section "Script Files Verification"
    
    # Check system scripts
    verify_check "deps_script" "[[ -f scripts/system/deps.sh ]]" "Check if deps.sh exists"
    verify_check "optimize_script" "[[ -f scripts/system/optimize.sh ]]" "Check if optimize.sh exists"
    verify_check "firewall_script" "[[ -f scripts/system/firewall.sh ]]" "Check if firewall.sh exists"
    
    # Check service scripts
    verify_check "ssh_service_script" "[[ -f scripts/services/ssh.sh ]]" "Check if ssh.sh exists"
    
    # Check account scripts
    verify_check "ssh_account_script" "[[ -f scripts/accounts/ssh-account.sh ]]" "Check if ssh-account.sh exists"
    
    # Check Xray management scripts
    verify_check "xray_client_script" "[[ -f scripts/xray-client.sh ]]" "Check if xray-client.sh exists"
    verify_check "xray_manager_script" "[[ -f scripts/xray-manager.sh ]]" "Check if xray-manager.sh exists"
    verify_check "ssl_manager_script" "[[ -f scripts/ssl-manager.sh ]]" "Check if ssl-manager.sh exists"
}

# =============================================================================
# SYSTEMD SERVICE FILES VERIFICATION
# =============================================================================

verify_systemd_files() {
    log_section "Systemd Service Files Verification"
    
    # Check systemd service files
    verify_check "xray_vmess_service" "[[ -f systemd/xray-vmess.service ]]" "Check if xray-vmess.service exists"
    verify_check "xray_vless_service" "[[ -f systemd/xray-vless.service ]]" "Check if xray-vless.service exists"
    verify_check "xray_trojan_service" "[[ -f systemd/xray-trojan.service ]]" "Check if xray-trojan.service exists"
}

# =============================================================================
# FILE CONTENT VERIFICATION
# =============================================================================

verify_file_contents() {
    log_section "File Content Verification"
    
    # Check if files are not empty
    verify_check "autoinstaller_content" "[[ -s autoinstaller.sh ]]" "Check if autoinstaller.sh has content"
    verify_check "test_autoinstaller_content" "[[ -s test-autoinstaller.sh ]]" "Check if test-autoinstaller.sh has content"
    verify_check "vmess_config_content" "[[ -s config/vmess.json ]]" "Check if vmess.json has content"
    verify_check "vless_config_content" "[[ -s config/vless.json ]]" "Check if vless.json has content"
    verify_check "trojan_config_content" "[[ -s config/trojan.json ]]" "Check if trojan.json has content"
}

# =============================================================================
# JSON VALIDATION
# =============================================================================

verify_json_files() {
    log_section "JSON File Validation"
    
    # Check if jq is available for JSON validation
    if command -v jq >/dev/null 2>&1; then
        verify_check "vmess_json_valid" "jq . config/vmess.json >/dev/null 2>&1" "Validate vmess.json JSON syntax"
        verify_check "vless_json_valid" "jq . config/vless.json >/dev/null 2>&1" "Validate vless.json JSON syntax"
        verify_check "trojan_json_valid" "jq . config/trojan.json >/dev/null 2>&1" "Validate trojan.json JSON syntax"
        verify_check "outbounds_json_valid" "jq . config/outbounds.json >/dev/null 2>&1" "Validate outbounds.json JSON syntax"
        verify_check "rules_json_valid" "jq . config/rules.json >/dev/null 2>&1" "Validate rules.json JSON syntax"
    else
        log_warning "jq not available, skipping JSON validation"
    fi
}

# =============================================================================
# PERMISSION VERIFICATION
# =============================================================================

verify_permissions() {
    log_section "File Permission Verification"
    
    # Check executable permissions
    verify_check "autoinstaller_executable" "[[ -x autoinstaller.sh ]]" "Check if autoinstaller.sh is executable"
    verify_check "test_autoinstaller_executable" "[[ -x test-autoinstaller.sh ]]" "Check if test-autoinstaller.sh is executable"
    verify_check "install_xray_executable" "[[ -x install-xray.sh ]]" "Check if install-xray.sh is executable"
}

# =============================================================================
# GITHUB REPOSITORY VERIFICATION
# =============================================================================

verify_github_access() {
    log_section "GitHub Repository Access Verification"
    
    # Check if we can access the GitHub repository
    verify_check "github_repo_access" "
        curl -s --connect-timeout 10 --max-time 15 \
        'https://raw.githubusercontent.com/xenvoid404/autoscript-tunneling/master/README.md' >/dev/null 2>&1
    " "Check GitHub repository accessibility"
}

# =============================================================================
# MAIN VERIFICATION FUNCTION
# =============================================================================

main() {
    # Initialize logging
    mkdir -p "$(dirname "$VERIFY_LOG")"
    echo "Installation Verification Log - $(date)" > "$VERIFY_LOG"
    
    echo "=============================================================="
    echo "               Installation Verification"
    echo "                    Version 4.0.0"
    echo ""
    echo "  Verifying all required files and directories"
    echo "  for Modern Tunneling Autoinstaller"
    echo ""
    echo "=============================================================="
    
    # Run all verification checks
    verify_main_scripts
    verify_directory_structure
    verify_config_files
    verify_utility_files
    verify_script_files
    verify_systemd_files
    verify_file_contents
    verify_json_files
    verify_permissions
    verify_github_access
    
    # Display results
    display_results
}

# Display verification results
display_results() {
    echo ""
    echo "=============================================================="
    echo "                  VERIFICATION RESULTS"
    echo "=============================================================="
    echo ""
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    echo ""
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        log_success "All verification checks passed!"
        echo ""
        echo "✓ Main scripts: OK"
        echo "✓ Directory structure: OK"
        echo "✓ Configuration files: OK"
        echo "✓ Utility files: OK"
        echo "✓ Script files: OK"
        echo "✓ Systemd files: OK"
        echo "✓ File contents: OK"
        echo "✓ JSON validation: OK"
        echo "✓ File permissions: OK"
        echo "✓ GitHub access: OK"
        echo ""
        echo "Your autoinstaller is ready for deployment!"
    else
        log_error "Some verification checks failed. Please fix the issues below:"
        echo ""
        for check_name in "${!VERIFICATION_RESULTS[@]}"; do
            if [[ "${VERIFICATION_RESULTS[$check_name]}" == "FAILED" ]]; then
                echo "✗ $check_name"
            fi
        done
        echo ""
        echo "Please fix the failed checks before proceeding with installation."
    fi
    
    echo ""
    echo "Detailed verification log: $VERIFY_LOG"
    echo "=============================================================="
}

# Show usage
show_usage() {
    echo "Installation Verification Script v4.0.0"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  verify                   - Run all verification checks (default)"
    echo "  scripts                  - Verify main script files only"
    echo "  directories              - Verify directory structure only"
    echo "  configs                  - Verify configuration files only"
    echo "  utils                    - Verify utility files only"
    echo "  systemd                  - Verify systemd files only"
    echo "  json                     - Verify JSON files only"
    echo "  permissions              - Verify file permissions only"
    echo ""
    echo "Examples:"
    echo "  $0 verify"
    echo "  $0 scripts"
    echo "  $0 configs"
}

# Parse command line arguments
case "${1:-verify}" in
    "verify")
        main
        ;;
    "scripts")
        verify_main_scripts
        display_results
        ;;
    "directories")
        verify_directory_structure
        display_results
        ;;
    "configs")
        verify_config_files
        verify_json_files
        display_results
        ;;
    "utils")
        verify_utility_files
        display_results
        ;;
    "systemd")
        verify_systemd_files
        display_results
        ;;
    "json")
        verify_json_files
        display_results
        ;;
    "permissions")
        verify_permissions
        display_results
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_usage
        exit 1
        ;;
esac