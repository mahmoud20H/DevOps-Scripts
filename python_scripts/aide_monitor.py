# ----------------------------------------------------------------------------------------------------------------# 
# This script monitors the system for integrity changes using AIDE.
# It should be run after aide_setup.py (manually or automatically via cron).
# Must be run with root privileges to access monitored files and logs.
# Creates log files in /var/log/aide-fim/python with execution results.
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#
import os
import sys
import shutil
import argparse
import subprocess
from datetime import datetime
from pathlib import Path

# ---------------------------------------
# Check OS and root privileges
# ---------------------------------------
if os.name != 'posix':
    print("ERROR: aide_monitor.py is intended to run on Linux systems only.")
    sys.exit(1)

if os.geteuid() != 0:
    print("ERROR: aide_monitor.py must be run as root.")
    print("Run: sudo python3 aide_monitor.py")
    sys.exit(1)

# ---------------------------------------
# Parse CLI Arguments & Determine Config Path
# ---------------------------------------
parser = argparse.ArgumentParser(description="AIDE File Integrity Monitor")
parser.add_argument(
    "-c", "--config",
    type=str,
    default=None,
    help="Path to the AIDE configuration file (default: auto-detected in /etc/aide/)"
)
args = parser.parse_args()

def resolve_config(config_arg):
    if config_arg:
        p = Path(config_arg)
        if p.exists():
            return p
        print(f"ERROR: Specified configuration file '{config_arg}' does not exist.")
        sys.exit(1)
    
    # Auto-detect config in /etc/aide
    candidates = [
        Path("/etc/aide/aide-lab.conf"),
        Path("/etc/aide/aide.conf")
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate

    # Search for any .conf in /etc/aide
    etc_aide = Path("/etc/aide")
    if etc_aide.exists():
        conf_files = list(etc_aide.glob("*.conf"))
        if conf_files:
            return conf_files[0]

    print("ERROR: No AIDE configuration file found.")
    print("Please run aide_setup.py first or specify a valid config using --config <path>")
    sys.exit(1)

AIDE_CONFIG = resolve_config(args.config)

# ---------------------------------------
# Configuration & Binary Checks
# ---------------------------------------
aide_bin = shutil.which("aide") or "/usr/bin/aide"
if not Path(aide_bin).exists() and shutil.which("aide") is None:
    print("ERROR: AIDE executable not found. Please install AIDE or run aide_setup.py.")
    sys.exit(1)

LOG_DIR = Path("/var/log/aide-fim/python")
LOG_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------
# Run AIDE Check
# ---------------------------------------
print(f"Running AIDE check using config: {AIDE_CONFIG} ...")
result = subprocess.run(
    [
        aide_bin,
        "--check",
        f"--config={AIDE_CONFIG}"
    ],
    capture_output=True,
    text=True
)

exit_code = result.returncode

# ---------------------------------------
# Prepare result containers & Parse AIDE output
# ---------------------------------------
added = []
removed = []
changed = []

section = None

if exit_code != 0 and (exit_code & 1 or exit_code & 2 or exit_code & 4):
    lines = result.stdout.splitlines()

    for line in lines:
        stripped = line.strip()
        if stripped == "Added entries:":
            section = "added"
            continue
        elif stripped == "Removed entries:":
            section = "removed"
            continue
        elif stripped == "Changed entries:":
            section = "changed"
            continue

        if section is None:
            continue

        if ":" not in line:
            continue

        path = line.split(":", 1)[1].strip()

        if not path.startswith("/"):
            continue

        if section == "added":
            added.append(path)
        elif section == "removed":
            removed.append(path)
        elif section == "changed":
            changed.append(path)

# Remove duplicates
added = list(dict.fromkeys(added))
removed = list(dict.fromkeys(removed))
changed = list(dict.fromkeys(changed))

# ---------------------------------------
# Timestamp and Status Determination
# ---------------------------------------
now = datetime.now()
timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
date = now.strftime("%Y-%m-%d")

if exit_code == 0:
    status = "CLEAN"
    log_file = LOG_DIR / f"{date}-clean.log"
    message = (
        f"{timestamp} [INFO] AIDE check completed successfully.\n"
        f"{timestamp} [INFO] No filesystem changes detected.\n"
    )

elif 1 <= exit_code <= 7:
    status = "CHANGE"
    log_file = LOG_DIR / f"{date}-change.log"
    message = (
        f"{timestamp} [WARNING] AIDE detected filesystem changes.\n"
        f"{timestamp} [WARNING] Exit code: {exit_code}\n"
    )

    if added:
        message += "\nAdded:\n"
        for path in added:
            message += f"  {path}\n"

    if removed:
        message += "\nRemoved:\n"
        for path in removed:
            message += f"  {path}\n"

    if changed:
        message += "\nChanged:\n"
        for path in changed:
            message += f"  {path}\n"

    message += "\n"

else:
    status = "ERROR"
    log_file = LOG_DIR / f"{date}-error.log"
    message = (
        f"{timestamp} [ERROR] AIDE check could not be completed.\n"
        f"{timestamp} [ERROR] Exit code: {exit_code}\n"
        f"{timestamp} [ERROR] {result.stderr.strip()}\n"
    )

# ---------------------------------------
# Write log & Terminal output
# ---------------------------------------
with open(log_file, "a") as file:
    file.write(message)

print("\nAIDE Monitor Summary")
print("====================")
print("Config File:", AIDE_CONFIG)
print("Status:     ", status)
print("Exit code:  ", exit_code)
print("Log File:   ", log_file)