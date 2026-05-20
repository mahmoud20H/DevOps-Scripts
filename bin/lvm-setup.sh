#!/bin/bash
################################################################################
# lvm-setup.sh — Interactive LVM (Logical Volume Management) Automation
################################################################################
#
# This script automates the end-to-end provisioning of LVM storage:
#   1. Validates root privileges and required dependencies
#   2. Presents available disks for interactive selection
#   3. Validates the selected disk is safe to use
#   4. Creates Physical Volume → Volume Group → Logical Volume
#   5. Formats, mounts, and persists the volume via /etc/fstab (UUID-based)
#
# Usage:
#   sudo ./bin/lvm-setup.sh
#   sudo LOG_LEVEL=DEBUG ./bin/lvm-setup.sh   # Verbose output
#
# Dependencies:
#   - lvm2 (pvcreate, vgcreate, lvcreate) — auto-installed if missing
#   - util-linux (lsblk, blkid)
#   - e2fsprogs (mkfs.ext4) or xfsprogs (mkfs.xfs)
#
# Safety:
#   - Requires explicit "YES" confirmation before touching any disk
#   - Backs up /etc/fstab before modification
#   - Uses UUID-based mounts (not /dev/mapper paths) for reliability
#
################################################################################

# =============================================================================
# BOOTSTRAP: Strict mode + shared libraries
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Unofficial Bash Strict Mode
set -euo pipefail

# Source shared libraries using the correct filenames (underscores, not hyphens)
# shellcheck source=../lib/logger.sh
source "${SCRIPT_DIR}/../lib/logger.sh"
# shellcheck source=../lib/error_handler.sh
source "${SCRIPT_DIR}/../lib/error_handler.sh"

# Install error traps and exit handlers from the shared error_handler library
setup_traps

# =============================================================================
# OPTIONAL CONFIGURATION FILE
# =============================================================================
# Look for a config file passed as an argument, or default to the conf/ folder.
# This allows operators to set defaults for the interactive prompts, but they can still override them at runtime.
CONFIG_FILE="${1:-${SCRIPT_DIR}/../conf/lvm-setup.conf}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
    log_info "Loaded defaults from: ${CONFIG_FILE}"
else
    log_debug "No config file found at ${CONFIG_FILE}. Proceeding purely interactively."
fi

# =============================================================================
# CONSTANTS
# =============================================================================
readonly FSTAB="/etc/fstab"
readonly SUPPORTED_FILESYSTEMS=("ext4" "xfs")

# =============================================================================
# FUNCTION: check_root
# Verifies the script is running with root/sudo privileges.
# LVM operations require root — there is no workaround.
# =============================================================================
check_root() {
    log_debug "Checking for root privileges (EUID=${EUID})"

    if [[ "${EUID}" -ne 0 ]]; then
        die "This script must be run as root or with sudo. Current EUID: ${EUID}" 1
    fi

    log_info "Root privilege check passed"
}

# =============================================================================
# FUNCTION: check_dependencies
# Ensures pvcreate, vgcreate, lvcreate (from lvm2) are available.
# If missing, offers interactive installation with OS auto-detection.
# =============================================================================
check_dependencies() {
    log_section "Dependency Check"

    local missing_tools=()

    # Check each required LVM binary
    for cmd in pvcreate vgcreate lvcreate; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing_tools+=("${cmd}")
            log_warn "Required command not found: ${cmd}"
        else
            log_debug "Found: ${cmd} at $(command -v "${cmd}")"
        fi
    done

    # If all tools are present, we're done
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        log_info "All LVM dependencies are satisfied"
        return 0
    fi

    # Tools are missing — prompt the user for interactive installation
    log_warn "Missing LVM tools: ${missing_tools[*]}"
    echo ""
    read -r -p "LVM tools are not installed. Would you like to install them now? (y/n): " install_choice

    if [[ "${install_choice}" != "y" && "${install_choice}" != "Y" ]]; then
        die "Cannot proceed without LVM tools. Install 'lvm2' manually and re-run." 1
    fi

    # Detect the OS family and install using the appropriate package manager
    install_lvm2
}

# =============================================================================
# FUNCTION: install_lvm2
# Detects OS family (Debian/Ubuntu vs RHEL/CentOS/Fedora) and installs lvm2.
# Falls back with a clear error if the distro is unrecognised.
# =============================================================================
install_lvm2() {
    log_info "Detecting operating system for package installation..."

    # Read os-release for reliable distro detection
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        local distro_id="${ID:-unknown}"
        local distro_like="${ID_LIKE:-}"
        log_debug "Detected distro ID='${distro_id}', ID_LIKE='${distro_like}'"
    else
        die "Cannot detect OS: /etc/os-release not found. Install 'lvm2' manually." 1
    fi

    # Match on ID or ID_LIKE to cover derivatives (e.g., Linux Mint → ubuntu)
    case "${distro_id} ${distro_like}" in
        *debian*|*ubuntu*)
            log_info "Debian/Ubuntu detected — installing lvm2 via apt"
            apt-get update -qq
            apt-get install -y -qq lvm2
            ;;
        *rhel*|*centos*|*fedora*|*rocky*|*alma*)
            log_info "RHEL/CentOS/Fedora detected — installing lvm2 via yum/dnf"
            if command -v dnf &>/dev/null; then
                dnf install -y lvm2
            else
                yum install -y lvm2
            fi
            ;;
        *)
            die "Unsupported distribution '${distro_id}'. Install 'lvm2' manually." 1
            ;;
    esac

    # Verify installation succeeded
    if ! command -v pvcreate &>/dev/null; then
        die "lvm2 installation appeared to succeed but 'pvcreate' is still not found." 1
    fi

    log_info "lvm2 installed successfully"
}

# =============================================================================
# FUNCTION: select_disk
# Displays available block devices and prompts the user to choose one.
# Sets the global SELECTED_DISK variable.
# =============================================================================
select_disk() {
    log_section "Disk Selection"

    log_info "Scanning available block devices..."
    echo ""

    # Show disks with useful columns; exclude loop/sr devices for clarity
    echo "────────────────────────────────────────────────────────────────────"
    lsblk -d -o NAME,SIZE,TYPE,MODEL,TRAN -e 7,11 --noheadings | while IFS= read -r line; do
        echo "  /dev/${line}"
    done
    echo "────────────────────────────────────────────────────────────────────"
    echo ""

    # Also show partition-level detail for reference
    log_info "Detailed partition layout:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT -e 7,11
    echo ""

    # Prompt until a valid block device path is provided
    while true; do
        read -r -p "Enter the disk to use for LVM (e.g., /dev/sdb): " SELECTED_DISK

        # Basic path validation
        if [[ ! "${SELECTED_DISK}" =~ ^/dev/ ]]; then
            log_error "Invalid path '${SELECTED_DISK}' — must start with /dev/"
            continue
        fi

        # Verify the device actually exists as a block device
        if [[ ! -b "${SELECTED_DISK}" ]]; then
            log_error "Device '${SELECTED_DISK}' does not exist or is not a block device"
            continue
        fi

        log_info "Selected disk: ${SELECTED_DISK}"
        break
    done
}

# =============================================================================
# FUNCTION: validate_disk
# Checks whether the selected disk already has partitions or a filesystem.
# If it does, requires an explicit "YES" to proceed (destructive operation).
# =============================================================================
validate_disk() {
    log_section "Disk Validation"

    local disk="${SELECTED_DISK}"
    local has_danger=false

    # ── Check 1: Existing partitions ──────────────────────────────────────
    local partition_count
    partition_count=$(lsblk -n -o NAME "${disk}" | wc -l)

    # lsblk always shows the device itself as the first line;
    # any additional lines are child partitions
    if [[ "${partition_count}" -gt 1 ]]; then
        log_warn "⚠  Disk '${disk}' already has $(( partition_count - 1 )) partition(s):"
        lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "${disk}"
        has_danger=true
    else
        log_info "No existing partitions found on '${disk}'"
    fi

    # ── Check 2: Existing filesystem directly on the disk ─────────────────
    local existing_fs
    existing_fs=$(blkid -o value -s TYPE "${disk}" 2>/dev/null || true)

    if [[ -n "${existing_fs}" ]]; then
        log_warn "⚠  Disk '${disk}' contains a '${existing_fs}' filesystem"
        has_danger=true
    else
        log_info "No filesystem signature detected on '${disk}'"
    fi

    # ── Check 3: Is the disk currently mounted? ───────────────────────────
    if grep -qs "${disk}" /proc/mounts; then
        log_warn "⚠  Disk '${disk}' or one of its partitions is currently MOUNTED"
        has_danger=true
    fi

    # ── If any danger flags were raised, require explicit confirmation ────
    if [[ "${has_danger}" == true ]]; then
        echo ""
        log_warn "═══════════════════════════════════════════════════════════════"
        log_warn "  WARNING: DESTRUCTIVE OPERATION"
        log_warn "  All existing data on '${disk}' will be PERMANENTLY DESTROYED."
        log_warn "  This action is IRREVERSIBLE."
        log_warn "═══════════════════════════════════════════════════════════════"
        echo ""
        read -r -p "Type YES (all caps) to confirm you want to wipe '${disk}': " confirm

        if [[ "${confirm}" != "YES" ]]; then
            die "Operation aborted by user. No changes were made." 0
        fi

        log_info "User confirmed destructive operation on '${disk}'"
    else
        log_info "Disk '${disk}' is clean — safe to proceed"
    fi
}

# =============================================================================
# FUNCTION: _prompt_new_vg_name
# Prompts the user for a new Volume Group name with validation.
# Sets the global VG_NAME variable.
# =============================================================================
_prompt_new_vg_name() {
    while true; do
        read -e -i "${DEFAULT_VG_NAME:-vg_data}" -p "Enter new Volume Group (VG) name: " VG_NAME

        if [[ -z "${VG_NAME}" ]]; then
            log_error "VG name cannot be empty"
            continue
        fi

        # VG names must be valid identifiers (alphanumeric, hyphens, underscores)
        if [[ ! "${VG_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
            log_error "VG name must start with a letter and contain only [a-zA-Z0-9_-]"
            continue
        fi

        # Ensure the name doesn't collide with an existing VG
        if vgs "${VG_NAME}" &>/dev/null; then
            log_error "Volume Group '${VG_NAME}' already exists. Choose a different name."
            continue
        fi

        break
    done
    log_info "New Volume Group name: ${VG_NAME}"
}

# =============================================================================
# FUNCTION: _prompt_new_lv_name
# Prompts the user for a new Logical Volume name with validation.
# Sets the global LV_NAME variable.
# =============================================================================
_prompt_new_lv_name() {
    while true; do
        read -e -i "${DEFAULT_LV_NAME:-lv_data}" -p "Enter new Logical Volume (LV) name: " LV_NAME

        if [[ -z "${LV_NAME}" ]]; then
            log_error "LV name cannot be empty"
            continue
        fi

        if [[ ! "${LV_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
            log_error "LV name must start with a letter and contain only [a-zA-Z0-9_-]"
            continue
        fi

        # If we have an existing VG, check for name collisions within it
        if [[ -n "${VG_NAME:-}" ]] && lvs "${VG_NAME}/${LV_NAME}" &>/dev/null; then
            log_error "Logical Volume '${LV_NAME}' already exists in VG '${VG_NAME}'. Choose a different name."
            continue
        fi

        break
    done
    log_info "New Logical Volume name: ${LV_NAME}"
}

# =============================================================================
# FUNCTION: collect_lvm_config
# Interactively prompts the user for LVM parameters.
# Pre-fills prompts using defaults if a config file was loaded.
# Sets VG_IS_NEW=true when a brand-new VG is being created, false when reusing.
# =============================================================================
collect_lvm_config() {
    log_section "LVM Configuration"

    # Track whether the user is creating a new VG or reusing an existing one.
    # This determines whether create_lvm calls vgcreate vs vgextend.
    VG_IS_NEW=true

    # ── Volume Group selection ────────────────────────────────────────────
    # Discover existing Volume Groups on the system
    local existing_vgs=()
    mapfile -t existing_vgs < <(vgs --noheadings -o vg_name 2>/dev/null | awk '{print $1}')

    if [[ ${#existing_vgs[@]} -gt 0 ]]; then
        # ── Show a numbered menu: existing VGs + "Create new" ─────────────
        log_info "Existing Volume Groups detected on this system:"
        echo ""
        echo "  ┌────────────────────────────────────────────────────────┐"
        echo "  │  #   Volume Group       Size       Free               │"
        echo "  ├────────────────────────────────────────────────────────┤"

        local idx=1
        for vg in "${existing_vgs[@]}"; do
            local vg_size vg_free
            vg_size=$(vgs --noheadings --nosuffix --units g -o vg_size "${vg}" 2>/dev/null | awk '{printf "%.1fG", $1}')
            vg_free=$(vgs --noheadings --nosuffix --units g -o vg_free "${vg}" 2>/dev/null | awk '{printf "%.1fG", $1}')
            printf "  │  %-4s%-20s%-11s%-15s│\n" "${idx})" "${vg}" "${vg_size}" "${vg_free}"
            (( idx++ ))
        done

        printf "  │  %-4s%-46s│\n" "${idx})" "✚ Create a new Volume Group"
        echo "  └────────────────────────────────────────────────────────┘"
        echo ""

        local create_new_option="${idx}"

        while true; do
            read -r -p "Select an option [1-${create_new_option}]: " vg_choice

            # Validate the input is a number in range
            if [[ ! "${vg_choice}" =~ ^[0-9]+$ ]] || \
               [[ "${vg_choice}" -lt 1 ]] || \
               [[ "${vg_choice}" -gt "${create_new_option}" ]]; then
                log_error "Invalid selection. Enter a number between 1 and ${create_new_option}"
                continue
            fi

            if [[ "${vg_choice}" -eq "${create_new_option}" ]]; then
                # User wants to create a new VG
                VG_IS_NEW=true
                _prompt_new_vg_name
            else
                # User selected an existing VG
                VG_NAME="${existing_vgs[$(( vg_choice - 1 ))]}"
                VG_IS_NEW=false
                log_info "Using existing Volume Group: ${VG_NAME}"
            fi
            break
        done
    else
        # No existing VGs — go straight to creating a new one
        log_info "No existing Volume Groups found — creating a new one"
        VG_IS_NEW=true
        _prompt_new_vg_name
    fi

    # ── Logical Volume selection ──────────────────────────────────────────
    if [[ "${VG_IS_NEW}" == false ]]; then
        # The user picked an existing VG — show its LVs and offer choices
        local existing_lvs=()
        mapfile -t existing_lvs < <(lvs --noheadings -o lv_name "${VG_NAME}" 2>/dev/null | awk '{print $1}')

        if [[ ${#existing_lvs[@]} -gt 0 ]]; then
            log_info "Existing Logical Volumes in '${VG_NAME}':"
            echo ""
            echo "  ┌──────────────────────────────────────────────────────┐"
            echo "  │  #   Logical Volume       Size       Path           │"
            echo "  ├──────────────────────────────────────────────────────┤"

            local lv_idx=1
            for lv in "${existing_lvs[@]}"; do
                local lv_size lv_path
                lv_size=$(lvs --noheadings --nosuffix --units g -o lv_size "${VG_NAME}/${lv}" 2>/dev/null | awk '{printf "%.1fG", $1}')
                lv_path="/dev/${VG_NAME}/${lv}"
                printf "  │  %-4s%-22s%-11s%-13s│\n" "${lv_idx})" "${lv}" "${lv_size}" "${lv_path}"
                (( lv_idx++ ))
            done

            printf "  │  %-4s%-48s│\n" "${lv_idx})" "✚ Create a new Logical Volume"
            echo "  └──────────────────────────────────────────────────────┘"
            echo ""

            local lv_create_option="${lv_idx}"

            while true; do
                read -r -p "Select an option [1-${lv_create_option}]: " lv_choice

                if [[ ! "${lv_choice}" =~ ^[0-9]+$ ]] || \
                   [[ "${lv_choice}" -lt 1 ]] || \
                   [[ "${lv_choice}" -gt "${lv_create_option}" ]]; then
                    log_error "Invalid selection. Enter a number between 1 and ${lv_create_option}"
                    continue
                fi

                if [[ "${lv_choice}" -eq "${lv_create_option}" ]]; then
                    # Create a new LV
                    _prompt_new_lv_name
                else
                    # Selected an existing LV — warn that it's already provisioned
                    LV_NAME="${existing_lvs[$(( lv_choice - 1 ))]}"
                    log_warn "Logical Volume '${LV_NAME}' already exists in VG '${VG_NAME}'"
                    log_warn "If you proceed, the script will attempt to format and mount it"
                    read -r -p "Are you sure you want to re-use this LV? (y/n): " reuse_confirm
                    if [[ "${reuse_confirm}" != "y" && "${reuse_confirm}" != "Y" ]]; then
                        continue
                    fi
                    log_info "Re-using existing Logical Volume: ${LV_NAME}"
                fi
                break
            done
        else
            log_info "No Logical Volumes found in '${VG_NAME}' — creating a new one"
            _prompt_new_lv_name
        fi
    else
        # New VG — always create a new LV
        _prompt_new_lv_name
    fi

    log_info "Volume Group:   ${VG_NAME} $(if [[ "${VG_IS_NEW}" == true ]]; then echo '(new)'; else echo '(existing)'; fi)"
    log_info "Logical Volume: ${LV_NAME}"

    # ── Logical Volume size ───────────────────────────────────────────────
    while true; do
        read -e -i "${DEFAULT_LV_SIZE:-100%FREE}" -p "Enter LV size (e.g., 10G, 500M, or 100%FREE): " LV_SIZE

        if [[ -z "${LV_SIZE}" ]]; then
            log_error "LV size cannot be empty"
            continue
        fi

        if [[ "${LV_SIZE}" =~ ^[0-9]+%(FREE|VG|PVS)$ ]] || [[ "${LV_SIZE}" =~ ^[0-9]+[KkMmGgTt]$ ]]; then
            break
        fi

        log_error "Invalid size '${LV_SIZE}'. Use formats like: 10G, 500M, 100%FREE"
    done
    log_info "Logical Volume size: ${LV_SIZE}"

    # ── Filesystem type ───────────────────────────────────────────────────
    while true; do
        read -e -i "${DEFAULT_FS_TYPE:-ext4}" -p "Enter filesystem type (ext4 or xfs): " FS_TYPE
        FS_TYPE="${FS_TYPE,,}"

        local valid=false
        for fs in "${SUPPORTED_FILESYSTEMS[@]}"; do
            if [[ "${FS_TYPE}" == "${fs}" ]]; then
                valid=true
                break
            fi
        done

        if [[ "${valid}" == true ]]; then break; fi
        log_error "Unsupported filesystem '${FS_TYPE}'. Choose: ${SUPPORTED_FILESYSTEMS[*]}"
    done
    log_info "Filesystem type: ${FS_TYPE}"

    # ── Mount point ───────────────────────────────────────────────────────
    while true; do
        read -e -i "${DEFAULT_MOUNT_POINT:-/mnt/data}" -p "Enter mount point path (e.g., /mnt/data): " MOUNT_POINT

        if [[ -z "${MOUNT_POINT}" ]]; then
            log_error "Mount point cannot be empty"
            continue
        fi

        if [[ "${MOUNT_POINT}" != /* ]]; then
            log_error "Mount point must be an absolute path (start with /)"
            continue
        fi

        if [[ -d "${MOUNT_POINT}" ]] && [[ -n "$(ls -A "${MOUNT_POINT}" 2>/dev/null)" ]]; then
            log_warn "Directory '${MOUNT_POINT}' exists and is NOT empty"
            read -r -p "Continue anyway? (y/n): " mp_confirm
            if [[ "${mp_confirm}" != "y" && "${mp_confirm}" != "Y" ]]; then
                continue
            fi
        fi
        break
    done
    log_info "Mount point: ${MOUNT_POINT}"

    # ── Summary / final confirmation ──────────────────────────────────────
    echo ""
    log_section "Configuration Summary"
    log_info "Disk:              ${SELECTED_DISK}"
    log_info "Volume Group:      ${VG_NAME}"
    log_info "Logical Volume:    ${LV_NAME}"
    log_info "LV Size:           ${LV_SIZE}"
    log_info "Filesystem:        ${FS_TYPE}"
    log_info "Mount Point:       ${MOUNT_POINT}"
    echo ""

    read -r -p "Proceed with LVM creation? (y/n): " final_confirm
    if [[ "${final_confirm}" != "y" && "${final_confirm}" != "Y" ]]; then
        die "Operation cancelled by user. No changes were made." 0
    fi
}

# =============================================================================
# FUNCTION: create_lvm
# Executes the LVM provisioning: PV → VG → LV → format → mount
# Each step is logged so the operator can see exactly what is happening.
# =============================================================================
create_lvm() {
    log_section "LVM Provisioning"

    local lv_path="/dev/${VG_NAME}/${LV_NAME}"

    # ── Step 1: Wipe any existing signatures (clean slate) ────────────────
    log_info "Wiping existing signatures on '${SELECTED_DISK}'..."
    wipefs --all --force "${SELECTED_DISK}"
    log_info "Disk signatures cleared"

    # ── Step 2: Create Physical Volume ────────────────────────────────────
    log_info "Creating Physical Volume on '${SELECTED_DISK}'..."
    pvcreate --force "${SELECTED_DISK}"
    log_info "Physical Volume created successfully"

    # ── Step 3: Create or extend Volume Group ─────────────────────────────
    if [[ "${VG_IS_NEW}" == true ]]; then
        log_info "Creating new Volume Group '${VG_NAME}' on '${SELECTED_DISK}'..."
        vgcreate "${VG_NAME}" "${SELECTED_DISK}"
        log_info "Volume Group '${VG_NAME}' created successfully"
    else
        log_info "Extending existing Volume Group '${VG_NAME}' with '${SELECTED_DISK}'..."
        vgextend "${VG_NAME}" "${SELECTED_DISK}"
        log_info "Volume Group '${VG_NAME}' extended successfully"
    fi

    # ── Step 4: Create Logical Volume ─────────────────────────────────────
    log_info "Creating Logical Volume '${LV_NAME}' (size: ${LV_SIZE})..."

    if [[ "${LV_SIZE}" =~ % ]]; then
        # Percentage-based allocation (e.g., 100%FREE)
        lvcreate -l "${LV_SIZE}" -n "${LV_NAME}" "${VG_NAME}"
    else
        # Absolute size allocation (e.g., 10G)
        lvcreate -L "${LV_SIZE}" -n "${LV_NAME}" "${VG_NAME}"
    fi

    log_info "Logical Volume '${lv_path}' created successfully"

    # ── Step 5: Format the Logical Volume ─────────────────────────────────
    log_info "Formatting '${lv_path}' as ${FS_TYPE}..."

    case "${FS_TYPE}" in
        ext4)
            mkfs.ext4 -F "${lv_path}"
            ;;
        xfs)
            mkfs.xfs -f "${lv_path}"
            ;;
    esac

    log_info "Filesystem '${FS_TYPE}' created successfully on '${lv_path}'"

    # ── Step 6: Create mount point and mount ──────────────────────────────
    log_info "Creating mount point '${MOUNT_POINT}'..."
    mkdir -p "${MOUNT_POINT}"

    log_info "Mounting '${lv_path}' at '${MOUNT_POINT}'..."
    mount "${lv_path}" "${MOUNT_POINT}"

    log_info "Volume mounted successfully"

    # Verify the mount
    if mountpoint -q "${MOUNT_POINT}"; then
        log_info "Verified: '${MOUNT_POINT}' is an active mount point"
        df -h "${MOUNT_POINT}"
    else
        die "Mount verification failed: '${MOUNT_POINT}' is not a mount point" 1
    fi
}

# =============================================================================
# FUNCTION: persist_mount
# Backs up /etc/fstab, then appends a UUID-based entry for the new volume.
# Using UUID (not /dev/mapper path) ensures reliability across reboots —
# device names can change, UUIDs do not.
# =============================================================================
persist_mount() {
    log_section "Persisting Mount in /etc/fstab"

    local lv_path="/dev/${VG_NAME}/${LV_NAME}"

    # ── Step 1: Get the UUID of the new Logical Volume ────────────────────
    log_info "Resolving UUID for '${lv_path}'..."
    local uuid
    uuid=$(blkid -s UUID -o value "${lv_path}")

    if [[ -z "${uuid}" ]]; then
        die "Could not determine UUID for '${lv_path}'. Filesystem may not have been created." 1
    fi

    log_info "UUID resolved: ${uuid}"

    # ── Step 2: Backup /etc/fstab ─────────────────────────────────────────
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local fstab_backup="${FSTAB}.backup.${timestamp}"

    log_info "Backing up '${FSTAB}' → '${fstab_backup}'..."
    cp "${FSTAB}" "${fstab_backup}"
    log_info "Backup created: ${fstab_backup}"

    # ── Step 3: Check for duplicate entries ───────────────────────────────
    if grep -qs "UUID=${uuid}" "${FSTAB}"; then
        log_warn "An fstab entry with UUID=${uuid} already exists — skipping"
        return 0
    fi

    if grep -qs "${MOUNT_POINT}" "${FSTAB}"; then
        log_warn "An fstab entry for mount point '${MOUNT_POINT}' already exists — skipping"
        return 0
    fi

    # ── Step 4: Append the new entry ──────────────────────────────────────
    # Format: UUID=<uuid>  <mount_point>  <fs_type>  defaults  0  2
    #   - 'defaults' → standard mount options (rw, suid, dev, exec, auto, nouser, async)
    #   - '0'        → do not dump (backup) this filesystem
    #   - '2'        → fsck order (check after root filesystem)
    local fstab_entry="UUID=${uuid}  ${MOUNT_POINT}  ${FS_TYPE}  defaults  0  2"

    log_info "Appending to ${FSTAB}:"
    log_info "  ${fstab_entry}"

    # Use tee -a to append; ensures we see it in the log
    echo "" >> "${FSTAB}"
    echo "# LVM volume: ${VG_NAME}/${LV_NAME} — added by lvm-setup.sh on ${timestamp}" >> "${FSTAB}"
    echo "${fstab_entry}" >> "${FSTAB}"

    log_info "fstab updated successfully"

    # ── Step 5: Validate fstab syntax ─────────────────────────────────────
    log_info "Validating fstab with 'findmnt --verify'..."
    if findmnt --verify --tab-file "${FSTAB}" &>/dev/null; then
        log_info "fstab validation passed"
    else
        log_warn "fstab validation reported warnings (review manually)"
        log_warn "Backup available at: ${fstab_backup}"
    fi
}

# =============================================================================
# FUNCTION: print_summary
# Displays a final summary of everything that was created.
# =============================================================================
print_summary() {
    local lv_path="/dev/${VG_NAME}/${LV_NAME}"

    log_section "LVM Setup Complete"

    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │                   LVM PROVISIONING SUMMARY                  │"
    echo "  ├─────────────────────────────────────────────────────────────┤"
    printf "  │  %-18s %-40s│\n" "Physical Volume:" "${SELECTED_DISK}"
    printf "  │  %-18s %-40s│\n" "Volume Group:" "${VG_NAME}"
    printf "  │  %-18s %-40s│\n" "Logical Volume:" "${lv_path}"
    printf "  │  %-18s %-40s│\n" "Filesystem:" "${FS_TYPE}"
    printf "  │  %-18s %-40s│\n" "Mount Point:" "${MOUNT_POINT}"
    printf "  │  %-18s %-40s│\n" "Persisted:" "Yes (UUID in /etc/fstab)"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo ""

    log_info "Useful commands:"
    log_info "  pvdisplay ${SELECTED_DISK}       — Show Physical Volume details"
    log_info "  vgdisplay ${VG_NAME}             — Show Volume Group details"
    log_info "  lvdisplay ${lv_path}             — Show Logical Volume details"
    log_info "  df -h ${MOUNT_POINT}             — Show disk usage"
    echo ""
}

# =============================================================================
# MAIN: Orchestrate the full LVM provisioning workflow
# =============================================================================
main() {
    log_section "Interactive LVM Setup"
    log_info "Starting LVM provisioning workflow..."

    # Phase 1: Pre-flight checks
    check_root
    check_dependencies

    # Phase 2: Interactive disk selection & validation
    select_disk
    validate_disk

    # Phase 3: Gather LVM configuration from the user
    collect_lvm_config

    # Phase 4: Execute LVM provisioning
    create_lvm

    # Phase 5: Persist mount across reboots
    persist_mount

    # Phase 6: Final summary
    print_summary

    log_info "LVM setup completed successfully. The volume is mounted and persistent."
}

# =============================================================================
# ENTRY POINT
# =============================================================================
main "$@"
