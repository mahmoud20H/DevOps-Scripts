# ----------------------------------------------------------------------------------------------------------------# 
# This script should be run on an Linux to set up the AIDE (Advanced Intrusion Detection Environment) tool
# setup. It will install AIDE, initialize the database, and configure it to run automatically on a schedule.
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#
import os
import subprocess
from pathlib import Path

# ========================================
#  Linux File Integrity Monitor
# checking prerequisites for AIDE installation 
# 1. Check if the script is running on a Linux system 
# 2. Check if the script is running with required privileges
# 3. Check if AIDE is already installed
# ========================================

if os.name != 'posix':
    print("This script is intended to run on Linux systems only.")
    exit(1)

if os.geteuid() != 0:
    print("This script must be run with root privileges.")
    exit(1)

if subprocess.run(["which", "aide"], capture_output=True).returncode == 0:
    print("AIDE is already installed.")
else:
    print("AIDE is not installed. Proceeding with installation...")
    response = input("Install AIDE? [Y/n]: ").lower()
    if response in ['y', 'yes']:
        install_command = ["apt-get", "update"]
        subprocess.run(install_command, check=True)
        install_command = ["apt-get", "install", "-y", "aide"]
        subprocess.run(install_command, check=True)
    else:
        print("Installation aborted.")
        exit(1)

# ---------------------------------------
# Ask for the AIDE configuration name 
# add a default value if the user doesn't provide one
# ---------------------------------------
name_config = input("Enter the name for the AIDE configuration (default: aide-lab): ") or "aide-lab"
config_path = Path("/etc/aide") / f"{name_config}.conf"
print(f"AIDE configuration path: {config_path}")

# Ensure the parent directory exists
config_path.parent.mkdir(parents=True, exist_ok=True)
# Create the file if it doesn't exist
config_path.touch(exist_ok=True)

# ---------------------------------------
# Ask for the paths to monitor with AIDE
# check if the provided paths exist and are valid
# continue asking for paths until the user decides to stop
# ---------------------------------------
until_user_stops = True
monitored_paths = []
while until_user_stops:
    user_path = input("Enter the path to monitor with AIDE (default: /etc): ") or "/etc"
    if not Path(user_path).exists():
        print(f"ERROR: The specified path '{user_path}' does not exist.")
        print("Please enter a file or directory.")
    else:
        print(f"Path added: {user_path}")
        monitored_paths.append(user_path)
        add_another = input("Add another path? [Y/n]: ").lower()
        if add_another not in ['y', 'yes']:
            until_user_stops = False
# print the list of monitored paths
print("Monitored paths:")
for i, path in enumerate(monitored_paths, start=1):
    print(f" {i}- {path}")

# TODO: Generate the AIDE configuration

# TODO: Initialize the AIDE database

# TODO: Ask whether to configure automatic monitoring
# If yes, set up a cron job for automatic monitoring

# TODO: Ask where logs should go & make default log file location