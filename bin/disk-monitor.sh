#!/bin/bash
# Unofficial Bash Strict Mode
set -euo pipefail

# Force log level to WARN 
export LOG_LEVEL="WARN"

# 1. Source the shared libraries Antigravity built
source "$(dirname "$0")/../lib/logger.sh"
source "$(dirname "$0")/../lib/error_handler.sh"
source "$(dirname "$0")/../lib/strict_mode.sh"


# 2. Activate the error safety net
setup_traps

# 3. Load the configuration file
CONFIG_FILE="${1:-conf/disk-monitor.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
    die "Configuration file missing: $CONFIG_FILE" 1
fi
source "$CONFIG_FILE"

log_section "Disk Monitor Started"
log_info "Checking partition: $TARGET_PARTITION"
log_info "Thresholds -> Warning: ${WARNING_THRESHOLD}% | Critical: ${CRITICAL_THRESHOLD}%"

# 4. Core Logic: Get current disk usage percentage
# df -h outputs disk info. grep finds the partition. awk gets the use% column. tr removes the '%' sign.
CURRENT_USAGE=$(df -h "$TARGET_PARTITION" | awk 'NR==2 {print $5}' | tr -d '%')

if [[ -z "$CURRENT_USAGE" ]]; then
    die "Could not determine disk usage for $TARGET_PARTITION. Does it exist?" 2
fi

log_debug "Current raw usage is ${CURRENT_USAGE}%"

# 5. Evaluate against thresholds
if [[ "$CURRENT_USAGE" -ge "$CRITICAL_THRESHOLD" ]]; then
    log_error "CRITICAL: Disk usage is at ${CURRENT_USAGE}% (Threshold: ${CRITICAL_THRESHOLD}%)"
    exit 2
elif [[ "$CURRENT_USAGE" -ge "$WARNING_THRESHOLD" ]]; then
    log_warn "WARNING: Disk usage is at ${CURRENT_USAGE}% (Threshold: ${WARNING_THRESHOLD}%)"
    exit 1
else
    log_info "OK: Disk usage is healthy at ${CURRENT_USAGE}%"
    exit 0
fi