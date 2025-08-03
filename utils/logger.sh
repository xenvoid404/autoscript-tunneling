#!/bin/bash

# Logger utility for Modern Tunneling Autoscript
# Provides standardized logging functions across all scripts

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file path
LOG_FILE=${LOG_FILE:-"/var/log/autoscript.log"}

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
    
    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" 2>/dev/null || true
    fi
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get process ID
get_pid() {
    echo $$
}

# Get script name
get_script_name() {
    basename "${BASH_SOURCE[1]:-unknown}"
}

# Write log message
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    local pid=$(get_pid)
    local script_name=$(get_script_name)
    
    echo "[$timestamp] [$level] [$pid] [$script_name] $message" >> "$LOG_FILE"
}

# Debug log
log_debug() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        write_log "DEBUG" "$1"
    fi
}

# Info log
log_info() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        write_log "INFO" "$1"
    fi
}

# Warning log
log_warn() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        write_log "WARN" "$1"
    fi
}

# Error log
log_error() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        write_log "ERROR" "$1"
    fi
}

# Fatal log
log_fatal() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_FATAL ]]; then
        write_log "FATAL" "$1"
    fi
}

# Function start log
log_function_start() {
    local function_name="$1"
    log_debug "Function started: $function_name"
}

# Function end log
log_function_end() {
    local function_name="$1"
    local exit_code="$2"
    
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
    
    log_debug "Executing command: $description"
    if eval "$command" >/dev/null 2>&1; then
        log_debug "Command succeeded: $description"
        return 0
    else
        log_error "Command failed: $description"
        return 1
    fi
}

# Export functions for use in other scripts
export -f init_logging
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_function_start
export -f log_function_end
export -f log_command