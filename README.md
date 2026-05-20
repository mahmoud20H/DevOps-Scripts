# 🛠️ DevOps Utility Suite

A collection of Bash scripts for system administration, monitoring, and maintenance. 


## 🏗️ Repository Architecture

```
DevOps-Scripts/
├── bin/                       # Executable scripts 
│   ├── disk-monitor.sh                 # script for disk monitor checks
│   ├── lvm-setup.sh                    # script for Interactive LVM (Logical Volume Management) Automation
├── lib/                       # Shared libraries (sourced, never executed)
│   ├── strict_mode.sh                  # Unofficial Bash Strict Mode
│   └── logger.sh                       # Timestamped, levelled logging (INFO/WARN/ERROR/DEBUG)
│   └── error_handler.sh                # Error handling and cleanup utilities
│
├── conf/                       # Configurations
│   └── disk-monitor.conf               # Disk Monitor Default Configuration to pass the values in it
│   └── lvm-setup.conf                  # LVM Setup Default Configuration, These values will pre-fill the interactive prompts.
|
├── tests/                      # test suites
│   └── test-disk-monitor.bats          # automated script for test bash disk-monitor script
│
├── .github/workflows/          # CI/CD pipelines
│   └── security-lint.yml               # GitHub Actions workflow for shellcheck & Misconfiguration Scan
│
└── README.md
```