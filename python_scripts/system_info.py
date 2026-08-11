import os
import socket
import platform
import getpass
# pip3 install psutil // To install psutil if not already installed
import psutil
import subprocess

def system_basics():
    print("=== System Basics ===")
    print("Hostname:", socket.gethostname())
    print("Current User:", getpass.getuser())
    print("OS:", platform.platform())
    print("Kernel Version:", platform.release())

def hardware_info():
    print("\n=== Hardware Info ===")
    print("CPU:", platform.processor())
    print("Cores:", os.cpu_count())
    print("Memory:", psutil.virtual_memory())
    print("Disk Usage:", psutil.disk_usage('/'))

def system_status():
    print("\n=== System Status ===")
    uptime = subprocess.check_output(["uptime", "-p"]).decode().strip()
    print("Uptime:", uptime)
    print("Load Average:", os.getloadavg())
    print("Processes:", len(psutil.pids()))

def networking_info():
    print("\n=== Networking Info ===")
    print("IP Address:", socket.gethostbyname(socket.gethostname()))
    print("Interfaces:", psutil.net_if_addrs())
    print("Connections:", psutil.net_connections())

if __name__ == "__main__":
    system_basics()
    hardware_info()
    system_status()
    networking_info()
