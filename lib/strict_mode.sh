#!/usr/bin/env bash
# =============================================================================
# strict_mode.sh — Unofficial Bash Strict Mode
# =============================================================================
# Source this file at the TOP of every script in the suite.
#
# Usage:
#   #!/usr/bin/env bash
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/strict_mode.sh"
#
# What it does:
#   set -e          → Exit immediately on any command failure.
#   set -u          → Treat unset variables as errors.
#   set -o pipefail → A pipeline fails if ANY command in it fails.
#   IFS=$'\n\t'     → Safer word splitting (newline + tab only).
# =============================================================================

[[ -n "${_STRICT_MODE_SH_LOADED:-}" ]] && return 0
readonly _STRICT_MODE_SH_LOADED=1

set -euo pipefail
IFS=$'\n\t'
