#!/bin/bash

# =============================================================================
# Autoinstaller Test Script v4.0.0
# Comprehensive testing for Modern Tunneling Autoinstaller
# 
# Tests:
# - System compatibility
# - File integrity
# - Service functionality
# - Configuration validation
# - Network connectivity
# - SSL certificates
# - Management scripts
#
# Author: Yuipedia
# License: MIT
# =============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test results
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging
readonly TEST_LOG="/var/log/autoscript-test.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$TEST_LOG"
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_description="$3"
    
    ((TOTAL_TESTS++))
    log_info "Running test: $test_name"
    log_info "Description: $test_description"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "✓ Test passed: $test_name"
        TEST_RESULTS["$test_name"]="PASSED"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "✗ Test failed: $test_name"
        TEST_RESULTS["$test_name"]="FAILED"
        ((FAILED_TESTS++))
        return 1
    fi
}

# =============================================================================
# SYSTEM COMPATIBILITY TESTS
# =============================================================================

test_system_compatibility() {
    log_section "System Compatibility Tests"
    
    # Test 1: Check if running as root
    run_test "root_check" "[[ \$EUID -eq 0 ]]" "Check if script is running as root"
    
    # Test 2: Check OS compatibility
    run_test "os_compatibility" "
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case \$OS in
                'Ubuntu') [[ \$VER -ge 22.04 ]] ;;
                'Debian GNU/Linux') [[ \$VER -ge 11 ]] ;;
                *) false ;;
            esac
        else
            false
        fi
    " "Check OS compatibility (Ubuntu 22.04+ or Debian 11+)"
    
    # Test 3: Check internet connectivity
    run_test "internet_connectivity" "ping -c 1 8.8.8.8 >/dev/null 2>&1" "Check internet connectivity"
    
    # Test 4: Check disk space
    run_test "disk_space" "
        available_space=\$(df / | awk 'NR==2 {print \$4}')
        available_mb=\$((available_space / 1024))
        [[ \$available_mb -ge 500 ]]
    " "Check available disk space (minimum 500MB)"
}

# =============================================================================
# FILE INTEGRITY TESTS
# =============================================================================

test_file_integrity() {
    log_section "File Integrity Tests"
    
    # Test 5: Check installation directories
    run_test "install_directories" "
        [[ -d /opt/autoscript ]] && \
        [[ -d /etc/autoscript ]] && \
        [[ -d /etc/xray ]] && \
        [[ -d /var/log/autoscript ]] && \
        [[ -d /etc/xray/ssl ]]
    " "Check if installation directories exist"
    
    # Test 6: Check configuration files
    run_test "config_files" "
        [[ -f /etc/xray/vmess.json ]] && \
        [[ -f /etc/xray/vless.json ]] && \
        [[ -f /etc/xray/trojan.json ]] && \
        [[ -f /etc/xray/outbounds.json ]] && \
        [[ -f /etc/xray/rules.json ]]
    " "Check if Xray configuration files exist"
    
    # Test 7: Check SSL certificates
    run_test "ssl_certificates" "
        [[ -f /etc/xray/ssl/cert.pem ]] && \
        [[ -f /etc/xray/ssl/key.pem ]]
    " "Check if SSL certificates exist"
    
    # Test 8: Check systemd service files
    run_test "systemd_services" "
        [[ -f /etc/systemd/system/xray-vmess.service ]] && \
        [[ -f /etc/systemd/system/xray-vless.service ]] && \
        [[ -f /etc/systemd/system/xray-trojan.service ]]
    " "Check if systemd service files exist"
    
    # Test 9: Check management scripts
    run_test "management_scripts" "
        [[ -x /usr/local/bin/autoscript-mgmt ]] && \
        [[ -x /usr/local/bin/xray-mgmt ]] && \
        [[ -x /usr/local/bin/xray-client ]]
    " "Check if management scripts exist and are executable"
}

# =============================================================================
# CONFIGURATION VALIDATION TESTS
# =============================================================================

test_configuration_validation() {
    log_section "Configuration Validation Tests"
    
    # Test 10: Validate JSON configurations
    run_test "json_validation" "
        jq . /etc/xray/vmess.json >/dev/null 2>&1 && \
        jq . /etc/xray/vless.json >/dev/null 2>&1 && \
        jq . /etc/xray/trojan.json >/dev/null 2>&1
    " "Validate JSON syntax in configuration files"
    
    # Test 11: Test Xray configurations
    run_test "xray_config_test" "
        xray run -test -config /etc/xray/vmess.json >/dev/null 2>&1 && \
        xray run -test -config /etc/xray/vless.json >/dev/null 2>&1 && \
        xray run -test -config /etc/xray/trojan.json >/dev/null 2>&1
    " "Test Xray configuration files"
    
    # Test 12: Test Nginx configuration
    run_test "nginx_config_test" "nginx -t >/dev/null 2>&1" "Test Nginx configuration"
    
    # Test 13: Validate SSL certificate
    run_test "ssl_validation" "openssl x509 -in /etc/xray/ssl/cert.pem -noout -text >/dev/null 2>&1" "Validate SSL certificate"
}

# =============================================================================
# SERVICE FUNCTIONALITY TESTS
# =============================================================================

test_service_functionality() {
    log_section "Service Functionality Tests"
    
    # Test 14: Check if services are enabled
    run_test "services_enabled" "
        systemctl is-enabled xray-vmess >/dev/null 2>&1 && \
        systemctl is-enabled xray-vless >/dev/null 2>&1 && \
        systemctl is-enabled xray-trojan >/dev/null 2>&1 && \
        systemctl is-enabled nginx >/dev/null 2>&1
    " "Check if services are enabled"
    
    # Test 15: Check if services are running
    run_test "services_running" "
        systemctl is-active xray-vmess >/dev/null 2>&1 && \
        systemctl is-active xray-vless >/dev/null 2>&1 && \
        systemctl is-active xray-trojan >/dev/null 2>&1 && \
        systemctl is-active nginx >/dev/null 2>&1
    " "Check if services are running"
    
    # Test 16: Check port availability
    run_test "port_availability" "
        ss -tuln | grep -q ':55 ' && \
        ss -tuln | grep -q ':58 ' && \
        ss -tuln | grep -q ':80 ' && \
        ss -tuln | grep -q ':443 '
    " "Check if required ports are listening"
}

# =============================================================================
# NETWORK CONNECTIVITY TESTS
# =============================================================================

test_network_connectivity() {
    log_section "Network Connectivity Tests"
    
    # Test 17: Test local port connectivity
    run_test "local_port_test" "
        timeout 5 bash -c '</dev/tcp/localhost/80' >/dev/null 2>&1 && \
        timeout 5 bash -c '</dev/tcp/localhost/443' >/dev/null 2>&1
    " "Test local port connectivity"
    
    # Test 18: Test Xray service connectivity
    run_test "xray_connectivity" "
        timeout 5 bash -c '</dev/tcp/localhost/55' >/dev/null 2>&1 && \
        timeout 5 bash -c '</dev/tcp/localhost/58' >/dev/null 2>&1
    " "Test Xray service connectivity"
}

# =============================================================================
# MANAGEMENT SCRIPT TESTS
# =============================================================================

test_management_scripts() {
    log_section "Management Script Tests"
    
    # Test 19: Test autoscript-mgmt status
    run_test "autoscript_mgmt_status" "/usr/local/bin/autoscript-mgmt status >/dev/null 2>&1" "Test autoscript-mgmt status command"
    
    # Test 20: Test xray-mgmt status
    run_test "xray_mgmt_status" "/usr/local/bin/xray-mgmt status >/dev/null 2>&1" "Test xray-mgmt status command"
    
    # Test 21: Test xray-client list
    run_test "xray_client_list" "/usr/local/bin/xray-client list >/dev/null 2>&1" "Test xray-client list command"
}

# =============================================================================
# SECURITY TESTS
# =============================================================================

test_security() {
    log_section "Security Tests"
    
    # Test 22: Check file permissions
    run_test "file_permissions" "
        [[ \$(stat -c %a /etc/xray/ssl/key.pem) == '600' ]] && \
        [[ \$(stat -c %a /etc/xray/ssl/cert.pem) == '644' ]]
    " "Check SSL certificate file permissions"
    
    # Test 23: Check UFW firewall status
    run_test "firewall_status" "ufw status | grep -q 'Status: active'" "Check if UFW firewall is active"
    
    # Test 24: Check SSH service
    run_test "ssh_service" "systemctl is-active ssh >/dev/null 2>&1" "Check if SSH service is running"
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

test_performance() {
    log_section "Performance Tests"
    
    # Test 25: Check system resources
    run_test "system_resources" "
        memory_usage=\$(free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}')
        [[ \$memory_usage -lt 90 ]]
    " "Check system memory usage (should be less than 90%)"
    
    # Test 26: Check disk usage
    run_test "disk_usage" "
        disk_usage=\$(df / | awk 'NR==2{printf \"%.0f\", \$5}' | sed 's/%//')
        [[ \$disk_usage -lt 90 ]]
    " "Check disk usage (should be less than 90%)"
}

# =============================================================================
# MAIN TEST FUNCTION
# =============================================================================

main() {
    # Initialize logging
    mkdir -p "$(dirname "$TEST_LOG")"
    echo "Autoinstaller Test Log - $(date)" > "$TEST_LOG"
    
    echo "=============================================================="
    echo "               Autoinstaller Test Suite"
    echo "                    Version 4.0.0"
    echo ""
    echo "  Comprehensive testing for Modern Tunneling Autoinstaller"
    echo "  Tests: System, Files, Services, Network, Security"
    echo ""
    echo "=============================================================="
    
    # Run all test suites
    test_system_compatibility
    test_file_integrity
    test_configuration_validation
    test_service_functionality
    test_network_connectivity
    test_management_scripts
    test_security
    test_performance
    
    # Display results
    display_results
}

# Display test results
display_results() {
    echo ""
    echo "=============================================================="
    echo "                  TEST RESULTS SUMMARY"
    echo "=============================================================="
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests passed! Installation is working correctly."
        echo ""
        echo "✓ System compatibility: OK"
        echo "✓ File integrity: OK"
        echo "✓ Configuration validation: OK"
        echo "✓ Service functionality: OK"
        echo "✓ Network connectivity: OK"
        echo "✓ Management scripts: OK"
        echo "✓ Security: OK"
        echo "✓ Performance: OK"
        echo ""
        echo "Your Modern Tunneling installation is ready for production!"
    else
        log_error "Some tests failed. Please check the issues below:"
        echo ""
        for test_name in "${!TEST_RESULTS[@]}"; do
            if [[ "${TEST_RESULTS[$test_name]}" == "FAILED" ]]; then
                echo "✗ $test_name"
            fi
        done
        echo ""
        echo "Please review the failed tests and fix the issues."
    fi
    
    echo ""
    echo "Detailed test log: $TEST_LOG"
    echo "=============================================================="
}

# Show usage
show_usage() {
    echo "Autoinstaller Test Suite v4.0.0"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  test                     - Run all tests (default)"
    echo "  system                   - Run system compatibility tests only"
    echo "  files                    - Run file integrity tests only"
    echo "  config                   - Run configuration validation tests only"
    echo "  services                 - Run service functionality tests only"
    echo "  network                  - Run network connectivity tests only"
    echo "  security                 - Run security tests only"
    echo "  performance              - Run performance tests only"
    echo ""
    echo "Examples:"
    echo "  $0 test"
    echo "  $0 system"
    echo "  $0 files"
}

# Parse command line arguments
case "${1:-test}" in
    "test")
        main
        ;;
    "system")
        test_system_compatibility
        display_results
        ;;
    "files")
        test_file_integrity
        display_results
        ;;
    "config")
        test_configuration_validation
        display_results
        ;;
    "services")
        test_service_functionality
        display_results
        ;;
    "network")
        test_network_connectivity
        display_results
        ;;
    "security")
        test_security
        display_results
        ;;
    "performance")
        test_performance
        display_results
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_usage
        exit 1
        ;;
esac