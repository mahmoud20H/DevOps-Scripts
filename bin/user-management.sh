#!/bin/bash
################################################################################
# user-management.sh — Interactive User & Permission Management
#
# Features:
#   - Create users with verified passwords and dedicated groups
#   - Modify supplementary groups and sudo privileges
#   - Delete users and their home directories
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

set -euo pipefail

# Source the shared libraries
# shellcheck source=/dev/null disable=SC1091
source "$(dirname "$0")/../lib/logger.sh"
# shellcheck source=/dev/null disable=SC1091
source "$(dirname "$0")/../lib/error_handler.sh"
# shellcheck source=/dev/null disable=SC1091
source "$(dirname "$0")/../lib/strict_mode.sh"

setup_traps

# Load Configuration
CONFIG_FILE="${1:-${SCRIPT_DIR}/../conf/user-management.conf}"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
else
    log_warn "Config not found at ${CONFIG_FILE}. Using hardcoded defaults."
    DEFAULT_SHELL="/bin/bash"
    ADMIN_GROUP="sudo"
fi

# =============================================================================
# Helper: Check Root
# =============================================================================
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "User management requires root privileges. Please run with sudo." 1
    fi
}

# =============================================================================
# Helper: Prompt for and verify password
# =============================================================================
get_verified_password() {
    local pass1 pass2
    while true; do
        read -r -s -p "Enter password for new user: " pass1
        echo ""
        read -r -s -p "Retype password to verify: " pass2
        echo ""
        
        if [[ -z "$pass1" ]]; then
            log_error "Password cannot be empty."
            continue
        fi

        if [[ "$pass1" == "$pass2" ]]; then
            # We return the password via a global variable to avoid subshell 
            # execution which might expose the password in process lists
            NEW_USER_PASSWORD="$pass1"
            break
        else
            log_error "Passwords do not match. Please try again."
        fi
    done
}

# =============================================================================
# Feature: Create User
# =============================================================================
create_user() {
    log_section "Create New User"
    read -r -p "Enter username to create: " username

    if id "$username" &>/dev/null; then
        log_error "User '$username' already exists."
        return
    fi

    get_verified_password

    log_info "Creating user '$username' with shell $DEFAULT_SHELL..."
    
    # -m: create home dir
    # -s: set shell
    # -U: create a group with the same name as the user
    useradd -m -s "$DEFAULT_SHELL" -U "$username"
    
    # Set the password securely
    echo "$username:$NEW_USER_PASSWORD" | chpasswd
    
    # Clear the password variable from memory
    unset NEW_USER_PASSWORD

    log_info "User '$username' created successfully with default standard (read-only system) permissions."
}

# =============================================================================
# Feature: Modify User Permissions (Groups)
# =============================================================================
modify_user() {
    log_section "Modify User Permissions"
    read -r -p "Enter username to modify: " username

    if ! id "$username" &>/dev/null; then
        log_error "User '$username' does not exist."
        return
    fi

    log_info "Current groups for $username: $(id -nG "$username")"
    
    echo "Select permission level to grant:"
    echo "1) Standard (Remove from admin group)"
    echo "2) Admin / Full Control (Add to $ADMIN_GROUP group)"
    echo "3) Add to specific custom groups"
    read -r -p "Selection [1-3]: " perm_choice

    case "$perm_choice" in
        1)
            # Remove from admin group. gpasswd -d is safer than usermod -G for removals
            if id -nG "$username" | grep -qw "$ADMIN_GROUP"; then
                gpasswd -d "$username" "$ADMIN_GROUP"
                log_info "Removed '$username' from '$ADMIN_GROUP'. User is now standard."
            else
                log_info "User is already a standard user."
            fi
            ;;
        2)
            usermod -aG "$ADMIN_GROUP" "$username"
            log_info "Granted Admin (sudo) privileges to '$username'."
            ;;
        3)
            read -r -p "Enter comma-separated groups to add (e.g., docker,developers): " custom_groups
            if [[ -n "$custom_groups" ]]; then
                usermod -aG "$custom_groups" "$username"
                log_info "Added '$username' to groups: $custom_groups"
            fi
            ;;
        *)
            log_error "Invalid selection."
            ;;
    esac
}

# =============================================================================
# Feature: Delete User
# =============================================================================
delete_user() {
    log_section "Delete User"
    read -r -p "Enter username to delete: " username

    if ! id "$username" &>/dev/null; then
        log_error "User '$username' does not exist."
        return
    fi

    # Safeguard: prevent deleting root or the current admin user
    if [[ "$username" == "root" || "$username" == "$SUDO_USER" ]]; then
        log_error "Protection fault: Cannot delete root or your current user account."
        return
    fi

    read -r -p "Are you sure you want to permanently delete '$username' and their home directory? (YES/no): " confirm
    if [[ "$confirm" == "YES" ]]; then
        log_info "Deleting user '$username' and home directory..."
        # -r removes the home directory and mail spool
        userdel -r "$username"
        log_info "User '$username' successfully deleted."
    else
        log_info "Deletion cancelled."
    fi
}

# =============================================================================
# MAIN MENU
# =============================================================================
main() {
    check_root

    while true; do
        echo ""
        log_section "User Management Menu"
        echo "1) Create User"
        echo "2) Modify User Permissions"
        echo "3) Delete User"
        echo "4) Exit"
        echo ""
        read -r -p "Enter your choice [1-4]: " choice

        case $choice in
            1) create_user ;;
            2) modify_user ;;
            3) delete_user ;;
            4) log_info "Exiting..."; exit 0 ;;
            *) log_error "Invalid option. Please try again." ;;
        esac
    done
}

main "$@"