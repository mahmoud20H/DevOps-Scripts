#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    USER_MGMT_SH="${REPO_ROOT}/bin/user-management.sh"
    USER_MGMT_CONF="${REPO_ROOT}/conf/user-management.conf"

    chmod +x "${USER_MGMT_SH}"
}

# Run user-management.sh the way an unprivileged operator would (even when Bats runs as root in CI).
run_user_management_as_non_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        if ! id bats-test-noroot &>/dev/null; then
            useradd -r -m -s /bin/bash bats-test-noroot
        fi
        run su -s /bin/bash bats-test-noroot -c "bash \"${USER_MGMT_SH}\""
    else
        run bash "${USER_MGMT_SH}"
    fi
}

@test "user-management fails if not run as root" {
    # Ensures check_root blocks non-root execution before the interactive menu.
    run_user_management_as_non_root

    [ "$status" -eq 1 ]
    [[ "$output" =~ "User management requires root privileges" ]]
}

@test "user-management syntax is completely valid" {
    run bash -n "${USER_MGMT_SH}"
    [ "$status" -eq 0 ]
}

@test "configuration file syntax is valid" {
    run bash -n "${USER_MGMT_CONF}"
    [ "$status" -eq 0 ]
}
