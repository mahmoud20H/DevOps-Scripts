# ----------------------------------------------------------------------------------------------------------------# 
# This script should be run on an Linux to set up the AIDE (Advanced Intrusion Detection Environment) tool
# setup. It will install AIDE, initialize the database, and configure it to run automatically on a schedule.
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#
import os
import subprocess

# ========================================
#  Linux File Integrity Monitor
# checking prerequisites for AIDE installation 
# 1. Check if the script is running on a Linux system 
# 2. Check if python3 is installed
# 3. Check if the script is running with required privileges
# 4. Check if AIDE is already installed
# ========================================

if os.name != 'posix':
    print("This script is intended to run on Linux systems only.")
    exit(1)

if not subprocess.run(["which", "python3"], capture_output=True).returncode == 0:
    print("Python3 is not installed.")
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

# TODO: Ask for the AIDE configuration name

# TODO: Ask what should be monitored using AIDE

# TODO: Generate the AIDE configuration

# TODO: Initialize the AIDE database

# TODO: Ask whether to configure automatic monitoring
# If yes, set up a cron job for automatic monitoring

# TODO: Ask where logs should go & make default log file location