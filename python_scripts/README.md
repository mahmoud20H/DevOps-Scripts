# Python Utilities & Monitoring Scripts

This directory contains Python scripts to assist with system monitoring, security integrity, notifications, and utility tasks.

---

## 📂 Script Catalog

### 1. Server Health Check & SNS Notification (`check_servers.py`)

#### Architecture

```
                EventBridge (Schedule)
                        │
                        ▼
                 AWS Lambda (Python)
                        │
        ┌───────────────┴───────────────┐
        │                               │
HTTP GET Requests                 CloudWatch Logs
        │
        ▼
  Multiple Services
        │
        ▼
Failure after retries?
        │
   Yes ─────► Amazon SNS ► Email / Slack / SMS
```

*   **File**: [check_servers.py]
*   **Why It's Used**: Automatically monitors the health of HTTP/HTTPS services (endpoints) and sends email/SMS notifications using AWS Simple Notification Service (SNS) if any of the endpoints become unreachable or return non-200 HTTP status codes. It is built to run as an AWS Lambda function or a standalone scheduled script.
*   **How to Use**:
    1.  **Configure Services**: Update the `SERVICES` list inside the script with the service name and the target URL:
        ```python
        SERVICES = [
            {'name': 'My App', 'url': 'https://example.com'},
        ]
        ```
    2.  **AWS Setup**:
        *   Update the `AWS_REGION`, `AWS_ACCOUNT_ID`, and `SNS_TOPIC_ARN` variables with your AWS account details.
        *   Ensure the environment running this script has appropriate IAM permissions to publish to the specified SNS Topic (`sns:Publish`) and CloudWatch Logs write actions (`logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`).
    3.  **Run via AWS Lambda**:
        *   Deploy it directly to AWS Lambda using Python 3.12 or attach a Lambda Layer using the handler function `check_servers.lambda_handler`
    4.  **Scheduling**:
        *   Use Amazon EventBridge.
        *   Example (Every X minutes):
    5.  **Security Improvements**:
        *   **Remove Hardcoded SNS Topic ARN**:
            Current: `SNS_TOPIC_ARN="arn:aws:sns:..."`
        *   **Better:**
            * Store in:
                * AWS Secrets Manager
                * AWS Parameter Store
                * Environment Variable
            * Recommended: AWS Parameter Store
            * Reason:
                * Easier deployment
                * No code changes
                * Supports encryption
---


### 2. Random Password Generator (`password_generator.py`)

*   **File**: [password_generator.py]
*   **Why It's Used**: Generates highly secure, randomized passwords based on user-defined criteria. 
    It helps DevOps engineers and system administrators quickly generate secure temporary passwords for new users, databases, or services.
*   **How to Use**:
    1.  Run the script in your terminal:
        ```bash
        python3 python_scripts/password_generator.py
        ```
    2.  Respond to the interactive prompts:
        *   *How many letters would you like in your password?*
        *   *How many symbols would you like?*
        *   *How many numbers would you like?*
    3.  The script will output a randomized, secure password using a mixture of upper/lowercase letters, digits, and special characters.
---

### 3. Linux System Information Script (`system_info.py`)
*   **File**: [system_info.py]

*   **Why It's Used**: Collects and reports detailed system information for Linux machines. 
    This script helps DevOps engineers, system administrators, and learners quickly gather essential data about their environment — including system basics, hardware specs, uptime, and networking details — without manually running multiple commands.

*   **How to Use**:
    1.  Run the script in your terminal:
        - To install psutil if not already installed `sudo apt install python3-psutil` OR
            `pip3 install psutil`
            ```bash  
            python3 system_info.py
            ```
    
    2.  The script will print system information to the terminal and also save it into a file named system_info1.txt.
    
    3.  If system_info1.txt already exists, the script will automatically create system_info2.txt, system_info3.txt, and so on, ensuring 
        no data is overwritten.
    
    4. Each file contains a snapshot of your system at the time of execution, including:
        - System Basics: Hostname, current user, OS, kernel version
        - Hardware Info: CPU model, core count, memory usage, disk usage
        - System Status: Uptime, load average, running processes count
        - Networking Info: IP address, active interfaces, open ports

*   **Security Improvements**:
    -  This script is already functional, but here are some enhancements you could add to make it more powerful and professional:
    
    1. Formatted Output: Use libraries like tabulate or rich to display results in tables with colors for readability.
    2. Command-Line Options: Add flags (via argparse) so users can choose which section to run, e.g. --network or --hardware.
    3. Logging: Save outputs not only to text files but also to a structured log format (JSON or CSV) for easier parsing.
    4. Monitoring Mode: Add a scheduler to run the script periodically and track changes in system status over time.

---

### 4. AIDE File Integrity Monitor Setup (`aide_setup.py`)

#### AIDE FIM Workflow Architecture

```
┌────────────────────────────────────────────────────────┐
│                   1. RUN AIDE SETUP                    │
│             (sudo python3 aide_setup.py)               │
└───────────────────────────┬────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
Install Package    Generate Config File   Initialize Baseline DB
 (apt/dnf/yum)    (/etc/aide/*.conf)      (/var/lib/aide/*.db)
                            │
                            ▼
               Configure Cron Schedule
              (/etc/cron.d/aide-monitor)
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                  2. RUN AIDE MONITOR                   │
│            (Manual or Scheduled via Cron)              │
│            (sudo python3 aide_monitor.py)              │
└───────────────────────────┬────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
 [CLEAN] No Changes   [CHANGE] Added/    [ERROR] Check Failed
  YYYY-MM-DD-clean    Changed/Removed    YYYY-MM-DD-error.log
      .log            YYYY-MM-DD-change
                            .log
```

*   **File**: [aide_setup.py]
*   **Why It's Used**: Automatically installs and configures AIDE (Advanced Intrusion Detection Environment) on Linux. It builds custom monitoring rules for selected directories (e.g. `/etc`, `/var`, `/usr`), initializes the baseline integrity database, and creates an automated cron job to run system integrity monitoring periodically.
*   **Prerequisites**:
    *   Linux Operating System (Debian/Ubuntu, RHEL/CentOS/Fedora, Arch Linux)
    *   Root / `sudo` privileges
*   **How to Use**:
    1.  Run the setup script with root privileges:
        ```bash
        sudo python3 python_scripts/aide_setup.py
        ```
    2.  Follow the interactive setup prompts:
        *   **Package Installation**: Automatically installs `aide` if not already installed.
        *   **Configuration Name**: Enter a name for your config (default: `aide-lab`).
        *   **Monitored Paths**: Enter directory paths to monitor (default: `/etc`). Add as many paths as needed.
        *   **Database Initialization**: The script builds and initializes the baseline integrity database under `/var/lib/aide/`.
        *   **Automatic Monitoring**: Choose to set up an automated cron schedule (Daily at 2:00 AM or Weekly on Sundays at 2:00 AM).
    3.  The setup script automatically links `aide_setup.py` with `aide_monitor.py` by placing a cron configuration file in `/etc/cron.d/aide-monitor`.

---

### 5. AIDE System Integrity Monitor (`aide_monitor.py`)

*   **File**: [aide_monitor.py]
*   **Why It's Used**: Scans the system against the baseline AIDE database created during setup. It detects added, modified, or deleted files, categorizes filesystem changes, and logs structured results to `/var/log/aide-fim/python/`.
*   **Prerequisites**:
    *   Must be run after `aide_setup.py` has initialized the AIDE database.
    *   Root / `sudo` privileges.
*   **How to Use**:
    1.  **Manual Execution**:
        ```bash
        sudo python3 python_scripts/aide_monitor.py
        ```
    2.  **Using Custom Config File**:
        If you created a custom configuration name during setup (e.g., `/etc/aide/custom-aide.conf`), pass it with the `-c` or `--config` option:
        ```bash
        sudo python3 python_scripts/aide_monitor.py --config /etc/aide/custom-aide.conf
        ```
    3.  **Automated Execution (Cron)**:
        If configured during setup, cron will run `aide_monitor.py` automatically. You can check the cron configuration at `/etc/cron.d/aide-monitor`.
    4.  **Reviewing Logs**:
        Logs are saved in `/var/log/aide-fim/python/` categorized by date and status:
        *   `YYYY-MM-DD-clean.log` - Generated when no filesystem changes are detected.
        *   `YYYY-MM-DD-change.log` - Contains list of Added, Removed, or Changed files.
        *   `YYYY-MM-DD-error.log` - Logged if AIDE encounters an error during execution.
