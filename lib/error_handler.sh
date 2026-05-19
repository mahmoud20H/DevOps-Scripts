#!/bin/bash
################################################################################
# error-handler.sh - Error handling and cleanup utilities
#
# This library provides utilities for consistent error handling, trap setup,
# and cleanup operations across all scripts.
#
# Usage:
#   source lib/logger.sh
#   source lib/error-handler.sh
#   setup_traps
#
# Exported Functions:
#   setup_traps         - Install error and exit handlers
#   handle_error        - Called on error (sets exit code)
#   handle_exit         - Called on exit (for cleanup)
#   register_cleanup    - Register custom cleanup function
################################################################################

set -euo pipefail

# Source logger if not already sourced
if ! declare -f log_error > /dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
fi

# Array to store cleanup functions
declare -a CLEANUP_FUNCTIONS=()

################################################################################
# Handle errors: log the error and set exit code
################################################################################
handle_error() {
    local line_number="$1"
    local error_code="$2"
    
    log_error "Script failed at line ${line_number} with exit code ${error_code}"
    
    # Call all registered cleanup functions
    _run_cleanup_functions
    
    exit "${error_code}"
}

################################################################################
# Handle script exit
################################################################################
handle_exit() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "Script completed successfully"
    else
        log_error "Script exited with code ${exit_code}"
    fi
}

################################################################################
# Run all registered cleanup functions
################################################################################
_run_cleanup_functions() {
    for func in "${CLEANUP_FUNCTIONS[@]}"; do
        if declare -f "$func" > /dev/null 2>&1; then
            log_debug "Running cleanup function: $func"
            "$func" || log_warn "Cleanup function $func failed"
        fi
    done
}

################################################################################
# Register a custom cleanup function
# Arguments: $1 - name of the function to call during cleanup
# 
# Example:
#   my_cleanup() {
#       rm -f /tmp/tempfile
#   }
#   register_cleanup my_cleanup
################################################################################
register_cleanup() {
    local func_name="$1"
    
    if [[ -z "$func_name" ]]; then
        log_error "register_cleanup: function name required"
        return 1
    fi
    
    CLEANUP_FUNCTIONS+=("$func_name")
    log_debug "Registered cleanup function: $func_name"
}

################################################################################
# Set up all error and exit handlers
# This should be called once at the beginning of each script
################################################################################
setup_traps() {
    # ERR trap: catch any non-zero exit
    trap 'handle_error ${LINENO} $?' ERR
    
    # EXIT trap: runs on any exit (normal or error)
    trap handle_exit EXIT
    
    log_debug "Error handlers and traps installed"
}

################################################################################
# Exit script with an error message
# Arguments: $1 - error message, $2 - exit code (optional, default 1)
################################################################################
die() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "$message"
    exit "$exit_code"
}

################################################################################
# Assert a condition, exit if false
# Arguments: $1 - condition to test, $2 - error message
# 
# Example:
#   assert "[[ -f /etc/passwd ]]" "passwd file does not exist"
################################################################################
assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    if ! eval "$condition"; then
        die "$message" 1
    fi
}

################################################################################
# Export functions for use in sourced scripts
################################################################################
export -f handle_error
export -f handle_exit
export -f register_cleanup
export -f setup_traps
export -f die
export -f assert
