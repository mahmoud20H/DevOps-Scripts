#!/bin/bash
################################################################################
# backup.sh — Interactive Automated Backup Utility
#
# Creates a compressed tar.gz archive from operator-selected paths, with
# defaults loaded from conf/backup.conf when present.
#
# Usage:
#   ./bin/backup.sh                          # Uses ../conf/backup.conf if it exists
#   ./bin/backup.sh /path/to/custom.conf     # Requires the config file to exist
#
# Dependencies:
#   - tar, date, mkdir, stat (or du), realpath
################################################################################

# =============================================================================
# BOOTSTRAP: Strict mode + shared libraries
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

set -euo pipefail

# shellcheck source=/dev/null disable=SC1091
source "${SCRIPT_DIR}/../lib/logger.sh"
# shellcheck source=/dev/null disable=SC1091
source "${SCRIPT_DIR}/../lib/error_handler.sh"

setup_traps

# =============================================================================
# CONFIGURATION FILE
# =============================================================================
# Default config path is optional (sourced silently when present).
# If the operator passes a path as $1, that file must exist or we halt.
DEFAULT_CONFIG="${SCRIPT_DIR}/../conf/backup.conf"

if [[ $# -ge 1 ]]; then
    CONFIG_FILE="$1"
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        die "Configuration file missing: ${CONFIG_FILE}" 1
    fi
    # shellcheck source=/dev/null disable=SC1090
    source "${CONFIG_FILE}"
else
    CONFIG_FILE="${DEFAULT_CONFIG}"
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null disable=SC1090
        source "${CONFIG_FILE}"
    fi
fi

# Built-in fallbacks when no config was loaded or keys were omitted
DEFAULT_SOURCES="${DEFAULT_SOURCES:-/etc /var/www}"
DEFAULT_DEST_DIR="${DEFAULT_DEST_DIR:-/backup}"

# =============================================================================
# FUNCTION: prompt_for_inputs
# Collects source paths and destination via readline pre-filled prompts.
# =============================================================================
prompt_for_inputs() {
    local sources_line dest_line

    log_section "Backup Configuration"
    log_info "Press Enter to accept bracketed defaults, or edit before confirming."

    # read -e enables readline; -i pre-fills the editable default (bash 4+)
    read -r -e -i "${DEFAULT_SOURCES}" -p "Paths to back up (space-separated): " sources_line
    read -r -e -i "${DEFAULT_DEST_DIR}" -p "Destination directory for archives: " dest_line

    # Trim leading/trailing whitespace from destination
    # shellcheck disable=SC2001
    DEST_DIR="$(echo "${dest_line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    SOURCES_LINE="${sources_line}"
}

# =============================================================================
# FUNCTION: validate_source_paths
# Ensures every token in SOURCES_LINE exists on the filesystem.
# Populates the global BACKUP_SOURCES array with validated absolute paths.
# =============================================================================
validate_source_paths() {
    local token
    BACKUP_SOURCES=()

    if [[ -z "${SOURCES_LINE// }" ]]; then
        log_error "No backup sources were provided."
        die "At least one source path is required." 1
    fi

    # Word-split on whitespace into path tokens
    for token in ${SOURCES_LINE}; do
        if [[ ! -e "${token}" ]]; then
            log_error "Invalid source path (not found): ${token}"
            die "Aborting backup due to invalid source path: ${token}" 1
        fi
        BACKUP_SOURCES+=("${token}")
        log_debug "Validated source: ${token}"
    done

    log_info "All ${#BACKUP_SOURCES[@]} source path(s) validated successfully."
}

# =============================================================================
# FUNCTION: ensure_destination_directory
# Creates the destination directory tree when it does not already exist.
# =============================================================================
ensure_destination_directory() {
    if [[ -d "${DEST_DIR}" ]]; then
        log_debug "Destination directory already exists: ${DEST_DIR}"
        return 0
    fi

    log_info "Destination does not exist; creating: ${DEST_DIR}"
    mkdir -p "${DEST_DIR}"
    log_info "Created destination directory: ${DEST_DIR}"
}

# =============================================================================
# FUNCTION: human_readable_size
# Returns a human-friendly size string for a regular file.
# Arguments: $1 — path to file
# =============================================================================
human_readable_size() {
    local file_path="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$(stat -c '%s' "${file_path}")"
    else
        du -h "${file_path}" | awk '{print $1}'
    fi
}

# =============================================================================
# FUNCTION: create_backup_archive
# Compresses validated sources into a timestamped tar.gz under DEST_DIR.
# =============================================================================
create_backup_archive() {
    local timestamp archive_name archive_path archive_abs archive_size

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    archive_name="backup_${timestamp}.tar.gz"
    archive_path="${DEST_DIR}/${archive_name}"

    log_section "Creating Backup Archive"
    log_info "Archive target: ${archive_path}"
    log_info "Sources: ${BACKUP_SOURCES[*]}"

    # -c create, -z gzip, -f file; paths are passed as separate arguments
    tar -czf "${archive_path}" "${BACKUP_SOURCES[@]}"

    archive_abs="$(realpath "${archive_path}")"
    archive_size="$(human_readable_size "${archive_path}")"

    log_info "Backup archive created successfully."
    log_info "Absolute path: ${archive_abs}"
    log_info "Final size: ${archive_size}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    log_section "Automated Backup Utility"

    prompt_for_inputs
    validate_source_paths
    ensure_destination_directory
    create_backup_archive

    log_info "Backup completed."
}

main "$@"
