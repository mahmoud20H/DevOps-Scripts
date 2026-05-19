# 🛠️ DevOps Utility Suite

A collection of Bash scripts for system administration, monitoring, and maintenance. 


## 🏗️ Repository Architecture

```
DevOps-Scripts/
├── bin/                        # Executable scripts 
│
├── lib/                        # Shared libraries (sourced, never executed)
│   ├── strict_mode.sh          # Unofficial Bash Strict Mode
│   └── logger.sh               # Timestamped, levelled logging (INFO/WARN/ERROR/DEBUG)
│   └── error-handler.sh        # Error handling and cleanup utilities
│
├── conf/                       # Configurations
│
├── tests/                      # test suites
│
├── .github/workflows/          # CI
│
└── README.md
```