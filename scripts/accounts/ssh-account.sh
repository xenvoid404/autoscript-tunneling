#!/bin/bash

# SSH Account Management Script for Modern Tunneling Autoscript
# Handles SSH account creation, deletion, and management

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/common.sh"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/validator.sh"
source "$PROJECT_ROOT/config/system.conf"

# Initialize logging
init_logging

# Account storage file
ACCOUNT_FILE="$ACCOUNT_DATA_DIR/ssh_accounts.txt"

# Function to initialize account management
init_ssh_account_management() {
    log_function_start "init_ssh_account_management"
    
    # Create account data directory
    create_directory "$ACCOUNT_DATA_DIR" "700"
    
    # Create account file if it doesn't exist
    if [[ ! -f "$ACCOUNT_FILE" ]]; then
        cat > "$ACCOUNT_FILE" << 'EOF'
# SSH Account Database
# Format: username:password:expiry_date:created_date:status
# Status: active, expired, disabled
EOF
        chmod 600 "$ACCOUNT_FILE"
        print_success "SSH account database initialized"
        log_info "SSH account database created"
    fi
    
    log_function_end "init_ssh_account_management" 0
}

# Function to generate secure password
generate_secure_password() {
    local length="${1:-12}"
    local password
    
    # Generate password with mixed characters
    password=$(tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c "$length")
    
    # Ensure password meets requirements
    if validate_password "$password" "$MIN_PASSWORD_LENGTH" "$MAX_PASSWORD_LENGTH" "$REQUIRE_SPECIAL_CHARS"; then
        echo "$password"
    else
        # Fallback to simpler generation
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
    fi
}

# Function to add SSH account
add_ssh_account() {
    log_function_start "add_ssh_account"
    
    local username="$1"
    local password="$2"
    local validity_days="${3:-$DEFAULT_ACCOUNT_VALIDITY}"
    
    # Validate inputs
    if ! validate_username "$username" "$MIN_USERNAME_LENGTH" "$MAX_USERNAME_LENGTH"; then
        print_error "Invalid username: $username"
        log_error "SSH account creation failed: invalid username $username"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        print_error "User $username already exists"
        log_error "SSH account creation failed: user $username already exists"
        return 1
    fi
    
    # Check if username is in account database
    if grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Username $username already in database"
        log_error "SSH account creation failed: username $username in database"
        return 1
    fi
    
    # Generate password if not provided
    if [[ -z "$password" ]]; then
        password=$(generate_secure_password 12)
    fi
    
    # Validate password
    if ! validate_password "$password" "$MIN_PASSWORD_LENGTH" "$MAX_PASSWORD_LENGTH" "$REQUIRE_SPECIAL_CHARS"; then
        print_error "Password validation failed"
        log_error "SSH account creation failed: invalid password for $username"
        return 1
    fi
    
    # Validate expiry days
    if ! validate_numeric "$validity_days" 1 "$MAX_ACCOUNT_VALIDITY"; then
        print_error "Invalid validity period: $validity_days days"
        log_error "SSH account creation failed: invalid validity for $username"
        return 1
    fi
    
    # Calculate expiry date
    local expiry_date
    expiry_date=$(date -d "+${validity_days} days" '+%Y-%m-%d')
    local created_date
    created_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    print_info "Creating SSH account for $username..."
    
    # Create system user
    if useradd -m -s /bin/bash "$username" &>/dev/null; then
        print_success "System user created: $username"
        log_info "System user created: $username"
    else
        print_error "Failed to create system user: $username"
        log_error "System user creation failed: $username"
        return 1
    fi
    
    # Set password
    if echo "$username:$password" | chpasswd &>/dev/null; then
        print_success "Password set for $username"
        log_info "Password set for user: $username"
    else
        print_error "Failed to set password for $username"
        userdel -r "$username" &>/dev/null
        log_error "Password setting failed for: $username"
        return 1
    fi
    
    # Add to account database
    echo "$username:$password:$expiry_date:$created_date:active" >> "$ACCOUNT_FILE"
    
    # Log access event
    log_access "SSH_ACCOUNT_CREATED" "Username: $username, Expiry: $expiry_date"
    
    print_success "SSH account created successfully"
    print_info "Username: $username"
    print_info "Password: $password"
    print_info "Expires: $expiry_date"
    
    log_function_end "add_ssh_account" 0
    return 0
}

# Function to delete SSH account
delete_ssh_account() {
    log_function_start "delete_ssh_account"
    
    local username="$1"
    
    # Validate username
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    # Check if user exists in system
    if ! id "$username" &>/dev/null; then
        print_warning "System user $username does not exist"
    else
        # Delete system user
        if userdel -r "$username" &>/dev/null; then
            print_success "System user deleted: $username"
            log_info "System user deleted: $username"
        else
            print_error "Failed to delete system user: $username"
            log_error "System user deletion failed: $username"
            return 1
        fi
    fi
    
    # Remove from account database
    if grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        sed -i "/^$username:/d" "$ACCOUNT_FILE"
        print_success "Account removed from database: $username"
        log_info "Account removed from database: $username"
    else
        print_warning "Username $username not found in database"
    fi
    
    # Kill user processes
    pkill -u "$username" &>/dev/null || true
    
    # Log access event
    log_access "SSH_ACCOUNT_DELETED" "Username: $username"
    
    print_success "SSH account deleted successfully"
    log_function_end "delete_ssh_account" 0
    return 0
}

# Function to extend account validity
extend_ssh_account() {
    log_function_start "extend_ssh_account"
    
    local username="$1"
    local additional_days="${2:-$DEFAULT_ACCOUNT_VALIDITY}"
    
    # Validate inputs
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    if ! validate_numeric "$additional_days" 1 "$MAX_ACCOUNT_VALIDITY"; then
        print_error "Invalid additional days: $additional_days"
        return 1
    fi
    
    # Check if account exists
    if ! grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Account not found: $username"
        return 1
    fi
    
    # Get current account info
    local account_line
    account_line=$(grep "^$username:" "$ACCOUNT_FILE")
    
    # Parse account data
    IFS=':' read -r user pass current_expiry created status <<< "$account_line"
    
    # Calculate new expiry date
    local new_expiry
    new_expiry=$(date -d "$current_expiry +${additional_days} days" '+%Y-%m-%d')
    
    # Update account database
    sed -i "s|^$username:.*|$username:$pass:$new_expiry:$created:active|" "$ACCOUNT_FILE"
    
    # Log access event
    log_access "SSH_ACCOUNT_EXTENDED" "Username: $username, New expiry: $new_expiry"
    
    print_success "Account validity extended"
    print_info "Username: $username"
    print_info "New expiry: $new_expiry"
    
    log_function_end "extend_ssh_account" 0
    return 0
}

# Function to disable SSH account
disable_ssh_account() {
    log_function_start "disable_ssh_account"
    
    local username="$1"
    
    # Validate username
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    # Check if account exists
    if ! grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Account not found: $username"
        return 1
    fi
    
    # Lock system account
    if passwd -l "$username" &>/dev/null; then
        print_success "System account locked: $username"
        log_info "System account locked: $username"
    else
        print_warning "Failed to lock system account: $username"
    fi
    
    # Update account database
    sed -i "s|^$username:\([^:]*:[^:]*:[^:]*:\).*|$username:\1disabled|" "$ACCOUNT_FILE"
    
    # Kill user processes
    pkill -u "$username" &>/dev/null || true
    
    # Log access event
    log_access "SSH_ACCOUNT_DISABLED" "Username: $username"
    
    print_success "SSH account disabled: $username"
    log_function_end "disable_ssh_account" 0
    return 0
}

# Function to enable SSH account
enable_ssh_account() {
    log_function_start "enable_ssh_account"
    
    local username="$1"
    
    # Validate username
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    # Check if account exists
    if ! grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Account not found: $username"
        return 1
    fi
    
    # Check if account is expired
    local account_line
    account_line=$(grep "^$username:" "$ACCOUNT_FILE")
    IFS=':' read -r user pass expiry created status <<< "$account_line"
    
    local current_date
    current_date=$(date '+%Y-%m-%d')
    
    if [[ "$expiry" < "$current_date" ]]; then
        print_error "Cannot enable expired account: $username (expired: $expiry)"
        return 1
    fi
    
    # Unlock system account
    if passwd -u "$username" &>/dev/null; then
        print_success "System account unlocked: $username"
        log_info "System account unlocked: $username"
    else
        print_warning "Failed to unlock system account: $username"
    fi
    
    # Update account database
    sed -i "s|^$username:\([^:]*:[^:]*:[^:]*:\).*|$username:\1active|" "$ACCOUNT_FILE"
    
    # Log access event
    log_access "SSH_ACCOUNT_ENABLED" "Username: $username"
    
    print_success "SSH account enabled: $username"
    log_function_end "enable_ssh_account" 0
    return 0
}

# Function to list SSH accounts
list_ssh_accounts() {
    log_function_start "list_ssh_accounts"
    
    print_section "SSH Account List"
    
    if [[ ! -f "$ACCOUNT_FILE" ]] || [[ ! -s "$ACCOUNT_FILE" ]]; then
        print_info "No SSH accounts found"
        return 0
    fi
    
    local current_date
    current_date=$(date '+%Y-%m-%d')
    
    printf "%-20s %-12s %-15s %-10s %s\n" "USERNAME" "STATUS" "EXPIRY" "DAYS LEFT" "CREATED"
    printf "%-20s %-12s %-15s %-10s %s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..19})"
    
    while IFS=':' read -r username password expiry created status; do
        # Skip comment lines
        [[ "$username" =~ ^#.*$ ]] && continue
        [[ -z "$username" ]] && continue
        
        # Calculate days left
        local days_left
        if [[ "$expiry" > "$current_date" ]]; then
            days_left=$(( ($(date -d "$expiry" +%s) - $(date -d "$current_date" +%s)) / 86400 ))
        else
            days_left="EXPIRED"
            status="expired"
        fi
        
        # Color coding for status
        local color=""
        case "$status" in
            "active")
                if [[ "$days_left" == "EXPIRED" ]]; then
                    color="$RED"
                    status="expired"
                elif [[ "$days_left" -le 3 ]]; then
                    color="$YELLOW"
                else
                    color="$GREEN"
                fi
                ;;
            "disabled") color="$PURPLE" ;;
            "expired") color="$RED" ;;
            *) color="$NC" ;;
        esac
        
        printf "${color}%-20s %-12s %-15s %-10s %s${NC}\n" \
            "$username" "$status" "$expiry" "$days_left" "${created% *}"
        
    done < "$ACCOUNT_FILE"
    
    log_function_end "list_ssh_accounts" 0
}

# Function to show account details
show_ssh_account() {
    log_function_start "show_ssh_account"
    
    local username="$1"
    
    # Validate username
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    # Check if account exists
    if ! grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Account not found: $username"
        return 1
    fi
    
    # Get account information
    local account_line
    account_line=$(grep "^$username:" "$ACCOUNT_FILE")
    IFS=':' read -r user password expiry created status <<< "$account_line"
    
    # Calculate days left
    local current_date
    current_date=$(date '+%Y-%m-%d')
    local days_left
    if [[ "$expiry" > "$current_date" ]]; then
        days_left=$(( ($(date -d "$expiry" +%s) - $(date -d "$current_date" +%s)) / 86400 ))
    else
        days_left="EXPIRED"
    fi
    
    # Get connection information
    local last_login=""
    local active_sessions=0
    
    if id "$username" &>/dev/null; then
        last_login=$(last -n 1 "$username" 2>/dev/null | head -n 1 | awk '{print $4, $5, $6, $7}')
        active_sessions=$(who | grep "^$username " | wc -l)
    fi
    
    print_section "SSH Account Details: $username"
    
    echo -e "${CYAN}Account Information:${NC}"
    echo "Username: $username"
    echo "Password: $password"
    echo "Status: $status"
    echo "Created: $created"
    echo "Expires: $expiry"
    echo "Days Left: $days_left"
    
    echo -e "\n${CYAN}Connection Information:${NC}"
    echo "Active Sessions: $active_sessions"
    echo "Last Login: ${last_login:-Never}"
    
    # Show server connection details
    local server_ip
    server_ip=$(get_public_ip)
    
    echo -e "\n${CYAN}Connection Details:${NC}"
    echo "Server IP: $server_ip"
    echo "SSH Port: $SSH_PORT"
    echo "Dropbear Port: $DROPBEAR_PORT"
    echo "Dropbear WS Port: $DROPBEAR_PORT_WS"
    
    log_function_end "show_ssh_account" 0
}

# Function to cleanup expired accounts
cleanup_expired_accounts() {
    log_function_start "cleanup_expired_accounts"
    
    print_section "Cleaning Up Expired Accounts"
    
    if [[ ! -f "$ACCOUNT_FILE" ]]; then
        print_info "No account database found"
        return 0
    fi
    
    local current_date
    current_date=$(date '+%Y-%m-%d')
    local expired_count=0
    
    while IFS=':' read -r username password expiry created status; do
        # Skip comment lines
        [[ "$username" =~ ^#.*$ ]] && continue
        [[ -z "$username" ]] && continue
        
        # Check if account is expired
        if [[ "$expiry" < "$current_date" && "$status" != "expired" ]]; then
            print_info "Disabling expired account: $username (expired: $expiry)"
            
            # Disable system account
            passwd -l "$username" &>/dev/null || true
            
            # Kill user processes
            pkill -u "$username" &>/dev/null || true
            
            # Update status in database
            sed -i "s|^$username:\([^:]*:[^:]*:[^:]*:\).*|$username:\1expired|" "$ACCOUNT_FILE"
            
            ((expired_count++))
            log_access "SSH_ACCOUNT_EXPIRED" "Username: $username"
        fi
    done < "$ACCOUNT_FILE"
    
    if [[ $expired_count -gt 0 ]]; then
        print_success "Disabled $expired_count expired accounts"
        log_info "Cleanup completed: $expired_count accounts expired"
    else
        print_info "No expired accounts found"
    fi
    
    log_function_end "cleanup_expired_accounts" 0
}

# Function to change account password
change_ssh_password() {
    log_function_start "change_ssh_password"
    
    local username="$1"
    local new_password="$2"
    
    # Validate username
    if ! validate_username "$username"; then
        print_error "Invalid username: $username"
        return 1
    fi
    
    # Check if account exists
    if ! grep -q "^$username:" "$ACCOUNT_FILE" 2>/dev/null; then
        print_error "Account not found: $username"
        return 1
    fi
    
    # Generate password if not provided
    if [[ -z "$new_password" ]]; then
        new_password=$(generate_secure_password 12)
    fi
    
    # Validate password
    if ! validate_password "$new_password" "$MIN_PASSWORD_LENGTH" "$MAX_PASSWORD_LENGTH" "$REQUIRE_SPECIAL_CHARS"; then
        print_error "Password validation failed"
        return 1
    fi
    
    # Update system password
    if echo "$username:$new_password" | chpasswd &>/dev/null; then
        print_success "System password updated for $username"
        log_info "System password updated for: $username"
    else
        print_error "Failed to update system password for $username"
        return 1
    fi
    
    # Update database
    sed -i "s|^$username:[^:]*:|$username:$new_password:|" "$ACCOUNT_FILE"
    
    # Log access event
    log_access "SSH_PASSWORD_CHANGED" "Username: $username"
    
    print_success "Password changed successfully"
    print_info "Username: $username"
    print_info "New Password: $new_password"
    
    log_function_end "change_ssh_password" 0
    return 0
}

# Main function for command-line interface
main() {
    # Initialize account management
    init_ssh_account_management
    
    # Parse command-line arguments
    case "${1:-}" in
        "add")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 add <username> [password] [validity_days]"
                exit 1
            fi
            add_ssh_account "$2" "$3" "$4"
            ;;
        "delete"|"del")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 delete <username>"
                exit 1
            fi
            delete_ssh_account "$2"
            ;;
        "extend")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 extend <username> [additional_days]"
                exit 1
            fi
            extend_ssh_account "$2" "$3"
            ;;
        "disable")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 disable <username>"
                exit 1
            fi
            disable_ssh_account "$2"
            ;;
        "enable")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 enable <username>"
                exit 1
            fi
            enable_ssh_account "$2"
            ;;
        "list")
            list_ssh_accounts
            ;;
        "show")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 show <username>"
                exit 1
            fi
            show_ssh_account "$2"
            ;;
        "cleanup")
            cleanup_expired_accounts
            ;;
        "password"|"passwd")
            if [[ -z "${2:-}" ]]; then
                print_error "Usage: $0 password <username> [new_password]"
                exit 1
            fi
            change_ssh_password "$2" "$3"
            ;;
        *)
            print_banner
            echo -e "${CYAN}SSH Account Management${NC}"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  add <username> [password] [days]  - Add new SSH account"
            echo "  delete <username>                 - Delete SSH account"
            echo "  extend <username> [days]          - Extend account validity"
            echo "  disable <username>                - Disable SSH account"
            echo "  enable <username>                 - Enable SSH account"
            echo "  list                              - List all SSH accounts"
            echo "  show <username>                   - Show account details"
            echo "  cleanup                           - Cleanup expired accounts"
            echo "  password <username> [password]    - Change account password"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi