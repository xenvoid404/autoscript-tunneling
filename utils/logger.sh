#!/bin/bash

# Logging utility for autoscript tunneling
# Provides structured logging with different levels

# Log configuration
readonly LOG_DIR="/var/log/autoscript"
readonly LOG_FILE="${LOG_DIR}/autoscript.log"
readonly ERROR_LOG="${LOG_DIR}/error.log"
readonly ACCESS_LOG="${LOG_DIR}/access.log"
readonly MAX_LOG_SIZE="10M"
readonly MAX_LOG_FILES=5

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Current log level (default: INFO)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Colors for console output
readonly LOG_COLOR_DEBUG='\033[0;36m'   # Cyan
readonly LOG_COLOR_INFO='\033[0;34m'    # Blue
readonly LOG_COLOR_WARN='\033[1;33m'    # Yellow
readonly LOG_COLOR_ERROR='\033[0;31m'   # Red
readonly LOG_COLOR_FATAL='\033[1;31m'   # Bold Red
readonly LOG_COLOR_RESET='\033[0m'      # Reset

# Initialize logging
init_logging() {
    # Create log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
    
    # Create log files if they don't exist
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$ACCESS_LOG"; do
        if [[ ! -f "$log_file" ]]; then
            touch "$log_file"
            chmod 644 "$log_file"
        fi
    done
    
    # Setup log rotation
    setup_log_rotation
    
    log_info "Logging initialized successfully"
}

# Setup log rotation using logrotate
setup_log_rotation() {
    cat > /etc/logrotate.d/autoscript << EOF
${LOG_DIR}/*.log {
    daily
    missingok
    rotate $MAX_LOG_FILES
    compress
    delaycompress
    notifempty
    create 644 root root
    size $MAX_LOG_SIZE
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
}

# Get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get log level name
get_level_name() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO)  echo "INFO"  ;;
        $LOG_LEVEL_WARN)  echo "WARN"  ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        $LOG_LEVEL_FATAL) echo "FATAL" ;;
        *)                echo "UNKNOWN" ;;
    esac
}

# Get log level color
get_level_color() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "$LOG_COLOR_DEBUG" ;;
        $LOG_LEVEL_INFO)  echo "$LOG_COLOR_INFO"  ;;
        $LOG_LEVEL_WARN)  echo "$LOG_COLOR_WARN"  ;;
        $LOG_LEVEL_ERROR) echo "$LOG_COLOR_ERROR" ;;
        $LOG_LEVEL_FATAL) echo "$LOG_COLOR_FATAL" ;;
        *)                echo "$LOG_COLOR_RESET" ;;
    esac
}

# Core logging function
write_log() {
    local level=$1
    local message="$2"
    local log_file="${3:-$LOG_FILE}"
    
    # Check if log level meets threshold
    if [[ $level -lt $LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp=$(get_timestamp)
    local level_name=$(get_level_name $level)
    local pid=$$
    local script_name=$(basename "${BASH_SOURCE[2]}")
    
    # Format log entry
    local log_entry="[$timestamp] [$level_name] [$pid] [$script_name] $message"
    
    # Write to log file
    echo "$log_entry" >> "$log_file"
    
    # Also write to console with color
    local color=$(get_level_color $level)
    echo -e "${color}[$level_name]${LOG_COLOR_RESET} $message"
    
    # If error or fatal, also write to error log
    if [[ $level -ge $LOG_LEVEL_ERROR ]]; then
        echo "$log_entry" >> "$ERROR_LOG"
    fi
}

# Public logging functions
log_debug() {
    write_log $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    write_log $LOG_LEVEL_INFO "$1"
}

log_warn() {
    write_log $LOG_LEVEL_WARN "$1"
}

log_error() {
    write_log $LOG_LEVEL_ERROR "$1"
}

log_fatal() {
    write_log $LOG_LEVEL_FATAL "$1"
    exit 1
}

# Log function execution
log_function_start() {
    local function_name="$1"
    log_debug "Function started: $function_name"
}

log_function_end() {
    local function_name="$1"
    local exit_code="${2:-0}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "Function completed successfully: $function_name"
    else
        log_error "Function failed with exit code $exit_code: $function_name"
    fi
}

# Log command execution
log_command() {
    local command="$1"
    local description="$2"
    
    log_info "Executing: $description"
    log_debug "Command: $command"
    
    local start_time=$(date +%s)
    
    # Execute command and capture output
    local output
    local exit_code
    
    if output=$(eval "$command" 2>&1); then
        exit_code=0
        log_debug "Command output: $output"
    else
        exit_code=$?
        log_error "Command failed with exit code $exit_code: $command"
        log_error "Command output: $output"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_debug "Command execution time: ${duration}s"
    
    return $exit_code
}

# Log access events (for account creation, etc.)
log_access() {
    local event="$1"
    local details="$2"
    local user="${3:-$(whoami)}"
    local ip="${4:-$(get_public_ip 2>/dev/null || echo 'unknown')}"
    
    local timestamp=$(get_timestamp)
    local log_entry="[$timestamp] [$user] [$ip] $event - $details"
    
    echo "$log_entry" >> "$ACCESS_LOG"
    log_info "ACCESS: $event - $details"
}

# Log system metrics
log_system_metrics() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}')
    local load_average=$(uptime | awk -F'load average:' '{print $2}')
    
    log_debug "System metrics - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}, Load: ${load_average}"
}

# Log file size check and rotation trigger
check_log_size() {
    local log_file="$1"
    local max_size_bytes
    
    # Convert size to bytes (assuming M suffix)
    max_size_bytes=$(echo "$MAX_LOG_SIZE" | sed 's/M$//' | awk '{print $1 * 1024 * 1024}')
    
    if [[ -f "$log_file" ]]; then
        local current_size=$(stat -c%s "$log_file")
        
        if [[ $current_size -gt $max_size_bytes ]]; then
            log_warn "Log file $log_file exceeds maximum size, triggering rotation"
            logrotate -f /etc/logrotate.d/autoscript
        fi
    fi
}

# Set log level
set_log_level() {
    case "$1" in
        "DEBUG"|"debug") LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "INFO"|"info")   LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "WARN"|"warn")   LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "ERROR"|"error") LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        "FATAL"|"fatal") LOG_LEVEL=$LOG_LEVEL_FATAL ;;
        *)
            log_error "Invalid log level: $1"
            return 1
            ;;
    esac
    
    log_info "Log level set to: $(get_level_name $LOG_LEVEL)"
}

# Clean old logs manually
clean_old_logs() {
    local days_to_keep="${1:-7}"
    
    log_info "Cleaning logs older than $days_to_keep days"
    
    find "$LOG_DIR" -name "*.log*" -type f -mtime +$days_to_keep -delete
    
    log_info "Log cleanup completed"
}

# Export functions
export -f init_logging setup_log_rotation get_timestamp
export -f write_log log_debug log_info log_warn log_error log_fatal
export -f log_function_start log_function_end log_command log_access
export -f log_system_metrics check_log_size set_log_level clean_old_logs