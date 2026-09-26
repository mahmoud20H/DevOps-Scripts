#!/usr/bin/env bats

# Resolve repo root from this file's location so tests work from any cwd
# (e.g. `bats tests/test_backup.bats` or `cd tests && bats test_backup.bats`).
setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    BACKUP_SH="${REPO_ROOT}/bin/backup.sh"
    BACKUP_CONF="${REPO_ROOT}/conf/backup.conf"

    chmod +x "${BACKUP_SH}"
}

@test "backup.sh passes bash syntax check" {
    run bash -n "${BACKUP_SH}"
    [ "$status" -eq 0 ]
}

@test "backup.conf has valid bash syntax" {
    run bash -n "${BACKUP_CONF}"
    [ "$status" -eq 0 ]
}

@test "backup.sh fails when an explicit config path is missing" {
    run bash "${BACKUP_SH}" "${REPO_ROOT}/conf/does-not-exist.conf"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file missing" ]]
}

@test "backup.sh fails when an explicit config path is fake" {
    run bash "${BACKUP_SH}" "/tmp/nonexistent-backup-config-$$.conf"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file missing" ]]
}
