#!/usr/bin/env bats

setup() {
    chmod +x bin/user-management.sh
}

@test "user-management fails if not run as root" {
    # This ensures the script's check_root function works and prevents 
    # unauthorized users from trying to execute the menu.
    run bash bin/user-management.sh
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "User management requires root privileges" ]]
}

@test "user-management syntax is completely valid" {
    # Verifies there are no broken loops, missing quotes, or syntax errors.
    run bash -n bin/user-management.sh
    [ "$status" -eq 0 ]
}

@test "configuration file syntax is valid" {
    # Ensure the config file can be sourced without bash errors
    run bash -n conf/user-management.conf
    [ "$status" -eq 0 ]
}