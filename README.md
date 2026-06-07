# 🛠️ DevOps Utility Suite

A collection of Bash scripts for system administration, monitoring, and maintenance. 


## 🏗️ Repository Architecture

```
DevOps-Scripts/
├── bin/                       # Executable scripts 
│   ├── disk-monitor.sh                 # script for disk monitor checks
│   ├── lvm-setup.sh                    # script for Interactive LVM (Logical Volume Management) Automation
│   └── user-management.sh              # Interactive user, group, and permission management
|
├── lib/                       # Shared libraries (sourced, never executed)
│   ├── strict_mode.sh                  # Unofficial Bash Strict Mode
│   └── logger.sh                       # Timestamped, levelled logging (INFO/WARN/ERROR/DEBUG)
│   └── error_handler.sh                # Error handling and cleanup utilities
│
├── conf/                       # Configurations
│   └── disk-monitor.conf               # Disk Monitor Default Configuration to pass the values in it
│   └── lvm-setup.conf                  # LVM Setup Default Configuration, These values will pre-fill the interactive prompts.
│   └── user-management.conf            # Default shells and admin group definitions
|
├── tests/                      # test suites
│   └── test-disk-monitor.bats          # automated script for test bash disk-monitor script
│   └── test-user-management.bats       # Root privilege and syntax checks for user management
│
├── .github/workflows/          # CI/CD pipelines
│   └── security-lint.yml               # GitHub Actions workflow for shellcheck & Misconfiguration Scan
│
└── README.md
```


## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/mahmoud20H/DevOps-Scripts.git
cd devops-scripts
```

### 2. Set Up Your Environment

```bash
# Edit conf/ directory with your settings 
# Example :-
vim conf/disk-monitor.conf
```

### 3. Verify Setup

```bash
# Make scripts executable
chmod +x bin/*.sh
chmod +x lib/*.sh

# Test the logger library
source lib/logger.sh
log_info "Logger is working!"
log_warn "This is a warning"
log_error "This is an error"
```

### 4. Run Tests Locally

```bash
# Install Bats (if not already installed)
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# Run tests 
# Example :-
bats tests/test-disk-monitor.bats

# Run all tests
bats tests/*.bats
```
🔒 Security
This repository includes automated security scanning:
CI/CD Security Checks

ShellCheck: Static analysis for common Bash errors
Trivy: Filesystem vulnerability scanning

Best Practices

✅ Never commit passwords or secrets to the repository
✅ Use environment variables or secret management systems
✅ All scripts must pass ShellCheck
✅ Configuration files are externalized, not hardcoded

## 🔄 CI/CD Pipeline

GitHub Actions automatically runs on:
- **Push** to main branches
- **Pull Requests** to main branches
- **Manual trigger** via workflow_dispatch

### Pipeline Steps

1. **ShellCheck**: Validates all shell scripts
2. **Security Scan**: Trivy scanning

### View Results

GitHub Actions logs are available in:
- Repository → Actions tab
- Each PR shows check status
- Failures include detailed logs