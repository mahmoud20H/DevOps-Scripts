#!/bin/bash
################################################################################
# logger.sh - Shared logging library for all devops scripts
# 
# This library provides standardized logging functions with timestamps.
# All scripts should source this file and use these functions for output.
#
# Usage:
#   source lib/logger.sh
#   log_info "Starting backup process"
#   log_warn "Disk usage above 80%"
#   log_error "Failed to connect to S3"
#   log_debug "Current value: $variable"
#
# Environment Variables:
#   LOG_LEVEL: Set to DEBUG, INFO, WARN, or ERROR (default: INFO)
#   LOG_FILE: Optional file path for logging (default: stdout only)
################################################################################

# Set default log level if not defined
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"

# ANSI color codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

################################################################################
# Internal Helper: Get current timestamp in ISO 8601 format
# Output: YYYY-MM-DD HH:MM:SS
################################################################################
_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

################################################################################
# Internal Helper: Check if a log level should be displayed
# Arguments: $1 - the log level to check (DEBUG, INFO, WARN, ERROR)
# Returns: 0 if should display, 1 if should skip
################################################################################
_should_log() {
    local level="$1"
    
    case "${LOG_LEVEL}" in
        DEBUG)
            return 0  # Display all levels
            ;;
        INFO)
            [[ "$level" != "DEBUG" ]]
            ;;
        WARN)
            [[ "$level" =~ ^(WARN|ERROR)$ ]]
            ;;
        ERROR)
            [[ "$level" == "ERROR" ]]
            ;;
        *)
            return 0  # Default to displaying
            ;;
    esac
}

################################################################################
# Internal Helper: Output log message to stdout and optionally to file
# Arguments: $1 - formatted message
################################################################################
_output_log() {
    local message="$1"
    
    echo -e "$message"
    
    if [[ -n "$LOG_FILE" ]]; then
        # Strip ANSI color codes before writing to file
        local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
        echo "$clean_message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

################################################################################
# Log an INFO message
# Arguments: $1 - message text
################################################################################
log_info() {
    local message="$1"
    
    if _should_log "INFO"; then
        local timestamp=$(_get_timestamp)
        local formatted="${COLOR_GREEN}[${timestamp}]${COLOR_RESET} [INFO] ${message}"
        _output_log "$formatted"
    fi
}

################################################################################
# Log a WARNING message
# Arguments: $1 - message text
################################################################################
log_warn() {
    local message="$1"
    
    if _should_log "WARN"; then
        local timestamp=$(_get_timestamp)
        local formatted="${COLOR_YELLOW}[${timestamp}]${COLOR_RESET} [WARN] ${message}"
        _output_log "$formatted"
    fi
}

################################################################################
# Log an ERROR message
# Arguments: $1 - message text
################################################################################
log_error() {
    local message="$1"
    
    if _should_log "ERROR"; then
        local timestamp=$(_get_timestamp)
        local formatted="${COLOR_RED}[${timestamp}]${COLOR_RESET} [ERROR] ${message}"
        _output_log "$formatted"
    fi
}

################################################################################
# Log a DEBUG message
# Arguments: $1 - message text
################################################################################
log_debug() {
    local message="$1"
    
    if _should_log "DEBUG"; then
        local timestamp=$(_get_timestamp)
        local formatted="${COLOR_BLUE}[${timestamp}]${COLOR_RESET} [DEBUG] ${message}"
        _output_log "$formatted"
    fi
}

################################################################################
# Print a section header (useful for demarcating stages of execution)
# Arguments: $1 - header text
################################################################################
log_section() {
    local header="$1"
    local line=$(printf '=%.0s' {1..80})
    
    _output_log "\n${COLOR_BLUE}${line}${COLOR_RESET}"
    _output_log "${COLOR_BLUE}${header}${COLOR_RESET}"
    _output_log "${COLOR_BLUE}${line}${COLOR_RESET}\n"
}

################################################################################
# Export functions for use in sourced scripts
################################################################################
export -f log_info
export -f log_warn
export -f log_error
export -f log_debug
export -f log_section
