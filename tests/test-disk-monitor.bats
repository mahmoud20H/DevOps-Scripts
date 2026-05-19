#!/usr/bin/env bats

setup() {
    # Create a temporary fake config file for testing
    TEST_CONF="/tmp/test-disk-monitor.conf"
    echo "TARGET_PARTITION=\"/\"" > "$TEST_CONF"
    echo "WARNING_THRESHOLD=1" >> "$TEST_CONF" # Force a warning
    echo "CRITICAL_THRESHOLD=101" >> "$TEST_CONF" # Impossible to hit
}

teardown() {
    # Clean up the fake config
    rm -f "$TEST_CONF"
}

@test "Fails gracefully if config is missing" {
    run bash bin/disk-monitor.sh "conf/does-not-exist.conf"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file missing" ]]
}

@test "Successfully reads fake config and triggers warning" {
    # Because we set warning to 1%, it should always trigger a warning (exit code 1)
    run bash bin/disk-monitor.sh "$TEST_CONF"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "WARNING: Disk usage is at" ]]
}