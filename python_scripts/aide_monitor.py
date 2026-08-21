import subprocess
from datetime import datetime
from pathlib import Path


# ---------------------------------------
# Configuration
# ---------------------------------------

AIDE_CONFIG = "/etc/aide/aide-lab.conf"
LOG_DIR = Path("/var/log/aide-fim/python")


# ---------------------------------------
# Prepare logging directory
# ---------------------------------------

LOG_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------
# Run AIDE
# ---------------------------------------

result = subprocess.run(
    [
        "sudo",
        "/usr/bin/aide",
        "--check",
        f"--config={AIDE_CONFIG}"
    ],
    capture_output=True,
    text=True
)


exit_code = result.returncode


# ---------------------------------------
# Prepare result containers
# ---------------------------------------

added = []
removed = []
changed = []

section = None


# ---------------------------------------
# Parse AIDE output
# ---------------------------------------

if exit_code != 0 and exit_code & 1 or exit_code & 2 or exit_code & 4:

    lines = result.stdout.splitlines()

    for line in lines:

        if line.strip() == "Added entries:":
            section = "added"
            continue

        elif line.strip() == "Removed entries:":
            section = "removed"
            continue

        elif line.strip() == "Changed entries:":
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


# ---------------------------------------
# Remove duplicates
# ---------------------------------------

added = list(dict.fromkeys(added))
removed = list(dict.fromkeys(removed))
changed = list(dict.fromkeys(changed))


# ---------------------------------------
# Current timestamp
# ---------------------------------------

now = datetime.now()

timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
date = now.strftime("%Y-%m-%d")


# ---------------------------------------
# Determine result
# ---------------------------------------

if exit_code == 0:

    status = "CLEAN"

    log_file = LOG_DIR / f"{date}-clean.log"

    message = (
        f"{timestamp} [INFO] AIDE check completed successfully.\n"
        f"{timestamp} [INFO] No filesystem changes detected.\n"
    )

elif exit_code & 1 or exit_code & 2 or exit_code & 4:

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
# Write log
# ---------------------------------------

with open(log_file, "a") as file:
    file.write(message)


# ---------------------------------------
# Terminal output
# ---------------------------------------

print("AIDE Monitor")
print("============")
print("Status:", status)
print("Exit code:", exit_code)
print("Log:", log_file)