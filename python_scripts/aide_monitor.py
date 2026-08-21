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

exit_code = result.returncode

added = []
removed = []
changed = []

section = None

if exit_code == 0:
    print("AIDE check completed successfully.")
    print("Status: CLEAN")

elif exit_code in [1, 2, 4]:

    lines = result.stdout.splitlines()

    for line in lines:

        # Detect which section we are in
        if line.strip() == "Added entries:":
            section = "added"
            continue

        elif line.strip() == "Removed entries:":
            section = "removed"
            continue

        elif line.strip() == "Changed entries:":
            section = "changed"
            continue

        # Ignore everything until we reach a section
        if section is None:
            continue

        # Only process lines containing a colon
        if ":" not in line:
            continue

        # Extract the path after the first colon
        path = line.split(":", 1)[1].strip()

        # Make sure we actually got a path
        if not path.startswith("/"):
            continue

        # Store the path in the correct list
        if section == "added":
            added.append(path)

        elif section == "removed":
            removed.append(path)

        elif section == "changed":
            changed.append(path)

    print("AIDE detected filesystem changes.")
    print("Exit code:", exit_code)

    if added:
        print("\nAdded:")
        for path in added:
            print("  ", path)

    if removed:
        print("\nRemoved:")
        for path in removed:
            print("  ", path)

    if changed:
        print("\nChanged:")
        for path in changed:
            print("  ", path)

else:
    print("AIDE check could not be completed.")
    print("Exit code:", exit_code)
    print("STDERR:")
    print(result.stderr)