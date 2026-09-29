# Python Utilities & Monitoring Scripts

This directory contains Python scripts for system monitoring, security integrity,
notifications, and utility tasks.

---

## Script Catalog

### 1. Server Health Check & SNS Notification (`check_servers.py`)

#### Architecture

```text
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

* **File:** [check_servers.py](check_servers.py)
* **Why it's used:** Monitors HTTP/HTTPS endpoints and publishes alerts through
  AWS SNS when a service is unreachable or returns a non-200 status. Designed
  for AWS Lambda or a scheduled standalone runner.
* **How to use:**
  1. Configure the `SERVICES` list with name/URL pairs:

     ```python
     SERVICES = [
         {'name': 'My App', 'url': 'https://example.com'},
     ]
     ```

  2. Set `AWS_REGION`, `AWS_ACCOUNT_ID`, and `SNS_TOPIC_ARN` for your account.
     The runtime needs IAM permissions for `sns:Publish` and CloudWatch Logs
     (`logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`).
  3. Deploy to AWS Lambda (Python 3.12+) with handler
     `check_servers.lambda_handler`, or run on a schedule you control.
  4. Schedule with Amazon EventBridge (for example, every N minutes).
  5. **Security:** Prefer Parameter Store, Secrets Manager, or environment
     variables for the SNS topic ARN instead of hard-coding
     `SNS_TOPIC_ARN="arn:aws:sns:..."` in source.

---

### 2. Random Password Generator (`password_generator.py`)

* **File:** [password_generator.py](password_generator.py)
* **Why it's used:** Builds randomized passwords from interactive length
  criteria for users, databases, and service accounts.
* **How to use:**
  1. Run:

     ```bash
     python3 python_scripts/password_generator.py
     ```

  2. Answer prompts for letters, symbols, and numbers.
  3. Copy the generated password from the terminal output.

---

### 3. Linux System Information Script (`system_info.py`)

* **File:** [system_info.py](system_info.py)
* **Why it's used:** Collects hostname, OS, hardware, uptime, and network
  details on Linux hosts without running many commands manually.
* **How to use:**
  1. Install `psutil` if needed (`sudo apt install python3-psutil` or
     `pip3 install psutil`), then run:

     ```bash
     python3 system_info.py
     ```

  2. Output is printed and saved as `system_info1.txt` (or the next free
     numbered file if one already exists).
  3. Each snapshot includes system basics, hardware, status, and networking
     sections.
* **Possible enhancements:** Table formatting (`tabulate`/`rich`), `argparse`
  flags per section, JSON/CSV export, and periodic monitoring mode.

---

### 4. AIDE File Integrity Monitor Setup (`aide_setup.py`)

#### AIDE FIM workflow

* You can review this post for more info:
  [Automate Linux security with AIDE](https://medium.com/@mahmoudahmed12492/stop-checking-logs-manually-automate-linux-security-with-aide-2f5df772fdfc)

```text
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

* **File:** [aide_setup.py](aide_setup.py)
* **Why it's used:** Installs and configures AIDE, defines monitored paths,
  initializes the baseline database, and optionally installs a cron schedule.
* **Prerequisites:** Linux (Debian/Ubuntu, RHEL/CentOS/Fedora, Arch) and root
  or sudo.
* **How to use:**
  1. Run setup:

     ```bash
     sudo python3 python_scripts/aide_setup.py
     ```

  2. Follow prompts for package install, config name, paths, DB init, and cron
     (daily or weekly).
  3. Cron integration writes `/etc/cron.d/aide-monitor` to invoke
     `aide_monitor.py`.

---

### 5. AIDE System Integrity Monitor (`aide_monitor.py`)

* **File:** [aide_monitor.py](aide_monitor.py)
* **Why it's used:** Compares the live filesystem to the AIDE baseline and
  logs added, changed, or removed files under `/var/log/aide-fim/python/`.
* **Prerequisites:** Completed `aide_setup.py` and root/sudo.
* **How to use:**
  1. Manual run:

     ```bash
     sudo python3 python_scripts/aide_monitor.py
     ```

  2. Custom config:

     ```bash
     sudo python3 python_scripts/aide_monitor.py --config /etc/aide/custom-aide.conf
     ```

  3. Cron (if configured during setup): inspect `/etc/cron.d/aide-monitor`.
  4. Log files: `YYYY-MM-DD-clean.log`, `YYYY-MM-DD-change.log`,
     `YYYY-MM-DD-error.log`.

---

### 6. Miles to Kilometer Converter (`mile_to_km.py`)

* **File:** [mile_to_km.py](mile_to_km.py)
* **Why it's used:** Tkinter GUI that converts miles to kilometers (four decimal
  places).
* **Prerequisites:** Python 3 with Tkinter (`sudo apt install python3-tk` on
  Debian/Ubuntu when needed).
* **How to use:**
  1. Run:

     ```bash
     python3 python_scripts/mile_to_km.py
     ```

  2. Enter miles and click **calculate**.

---

### 7. Structured JSON Log Analyzer (`Log_analysis.py`)

* **File:** [Log_analysis.py](Log_analysis.py)
* **Why it's used:** Parses JSON logs (for example MongoDB `db.log`), builds a
  pandas DataFrame, filters severity `E`, and summarizes top errors and hourly
  counts.
* **Prerequisites:** `pandas` (`pip3 install pandas`) and `db.log` in the
  working directory.
* **How to use:**
  1. Install dependencies:

     ```bash
     pip3 install pandas
     ```

  2. Place `db.log` in the current directory.
  3. Run:

     ```bash
     python3 python_scripts/Log_analysis.py
     ```

  4. Review **Top 10 Errors** and **Errors per Hour** in the output.
