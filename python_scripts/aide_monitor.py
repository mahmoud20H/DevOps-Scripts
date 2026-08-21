import subprocess

result = subprocess.run(
    [
        "sudo",
        "/usr/bin/aide",
        "--check",
        "--config=/etc/aide/aide-lab.conf"
    ],
    capture_output=True,
    text=True
)
# check the return code and print the output
if result.returncode == 0:
    print("AIDE check completed successfully.")
    print("Exit code:", result.returncode)
    print("Output: Checksum matches, no changes detected.")
elif result.returncode in [1, 2, 4]:
    if result.returncode & 4:
        print("AIDE check completed.\nFiles modified detected.")
    if result.returncode & 1:
        print("AIDE check completed.\nFiles added detected.")
    if result.returncode & 2:
        print("AIDE check completed.\nFiles deleted detected.")
    print("Exit code:", result.returncode)
    print("Output:")
    print(result.stdout)
else:
    print("AIDE check encountered an unexpected error.")
    print("Exit code:", result.returncode)
    print("STDERR:")
    print(result.stderr)