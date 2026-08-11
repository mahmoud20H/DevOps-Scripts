import os
import socket
import platform
import getpass
# pip3 install psutil // To install psutil if not already installed
import psutil
import subprocess

def system_basics():
    lines = []
    lines.append("=== System Basics ===")
    lines.append(f"Hostname: {socket.gethostname()}")
    lines.append(f"Current User: {getpass.getuser()}")
    lines.append(f"OS: {platform.platform()}")
    lines.append(f"Kernel Version: {platform.release()}")
    return "\n".join(lines)

def hardware_info():
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
    lines = []
    lines.append("\n=== System Status ===")
    uptime = subprocess.check_output(["uptime", "-p"]).decode().strip()
    lines.append(f"Uptime: {uptime}")
    lines.append(f"Load Average: {os.getloadavg()}")
    lines.append(f"Processes: {len(psutil.pids())}")
    return "\n".join(lines)

def networking_info():
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
    counter = 1
    while True:
        filename = f"{base_name}{counter}{extension}"
        if not os.path.exists(filename):
            return filename
        counter += 1

def save_output(content):
    filename = get_next_filename()
    with open(filename, "w") as f:
        f.write(content)
    print(f"\nSystem info saved to {filename}")

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
