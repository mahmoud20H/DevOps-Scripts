# ----------------------------------------------------------------------------------------------------------------# 
# This script for system information collection and monitoring.
# It gathers system basics, hardware info, system status, and networking info.
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#
import os
import socket
import platform
import getpass
# pip3 install psutil // To install psutil if not already installed
import psutil
import subprocess

def system_basics():
    """Collects basic system information including hostname, current user, OS, and kernel version.
    Returns:
        str: Formatted string containing system basics."""
    lines = []
    lines.append("=== System Basics ===")
    lines.append(f"Hostname: {socket.gethostname()}")
    lines.append(f"Current User: {getpass.getuser()}")
    lines.append(f"OS: {platform.platform()}")
    lines.append(f"Kernel Version: {platform.release()}")
    return "\n".join(lines)

def hardware_info():
    """Collects hardware information including CPU, cores, and memory details.
    Returns:
        str: Formatted string containing hardware information."""
    lines = []
    lines.append("\n=== Hardware Info ===")
    lines.append(f"CPU: {platform.processor()}")
    lines.append(f"Cores: {os.cpu_count()}")
    mem = psutil.virtual_memory()
    lines.append(f"Memory: Total={mem.total}, Used={mem.used}, Free={mem.free}")
    disk = psutil.disk_usage('/')
    lines.append(f"Disk Usage: Total={disk.total}, Used={disk.used}, Free={disk.free}, Percent={disk.percent}%")
    return "\n".join(lines)

def system_status():
    """Collects system status information including uptime, load average, and process count.
    Returns:
        str: Formatted string containing system status information."""
    lines = []
    lines.append("\n=== System Status ===")
    uptime = subprocess.check_output(["uptime", "-p"]).decode().strip()
    lines.append(f"Uptime: {uptime}")
    lines.append(f"Load Average: {os.getloadavg()}")
    lines.append(f"Processes: {len(psutil.pids())}")
    return "\n".join(lines)

def networking_info():
    """Collects networking information including IP address, interfaces, and open ports.
    Returns:
        str: Formatted string containing networking information.""" 
    lines = []
    lines.append("\n=== Networking Info ===")
    lines.append(f"IP Address: {socket.gethostbyname(socket.gethostname())}")
    # Show only interface names
    interfaces = ", ".join(psutil.net_if_addrs().keys())
    lines.append(f"Interfaces: {interfaces}")
    # Show only listening ports
    ports = [conn.laddr.port for conn in psutil.net_connections() if conn.status == 'LISTEN']
    lines.append(f"Open Ports: {ports}")
    return "\n".join(lines)

def get_next_filename(base_name="system_info", extension=".txt"):
    """Generates the next available filename to avoid overwriting existing files.
    Args:
        base_name (str): Base name of the file.
        extension (str): File extension."""
    counter = 1
    while True:
        filename = f"{base_name}{counter}{extension}"
        if not os.path.exists(filename):
            return filename
        counter += 1

def save_output(content):
    """Saves the collected system information to a uniquely named file.
    Args:
        content (str): The content to be saved to the file."""
    filename = get_next_filename()
    with open(filename, "w") as f:
        f.write(content)
    print(f"\nSystem info saved to {filename}")

# Only run this code if the file is being executed directly, not when it’s imported.
# note: The following code block is for demonstration purposes and can be removed or modified as needed.
if __name__ == "__main__":
    # Collect all sections
    output = []
    output.append(system_basics())
    output.append(hardware_info())
    output.append(system_status())
    output.append(networking_info())

    final_output = "\n".join(output)

    # Print to terminal
    print(final_output)

    # Save to file
    save_output(final_output)
