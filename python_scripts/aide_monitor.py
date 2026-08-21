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

print("Exit code:", result.returncode)
print("Output:")
print(result.stdout)
print("STDERR:")
print(result.stderr)