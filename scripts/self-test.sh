#!/usr/bin/env bash
# Runs fleet's gates against a scratch git copy of fixtures/sample-app and checks every exit code and evidence file.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fleet="$root/ops-cli/fleet"
work="$(mktemp -d "${TMPDIR:-/tmp}/fleet-self-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
app="$work/sample-app"
log="$work/last.log"
passed=0
failed=0

ok() {
    passed=$((passed + 1))
    printf 'ok   %s\n' "$1"
}

not_ok() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
    if [[ -s "$log" ]]; then
        sed 's/^/     | /' "$log" | tail -n 40
    fi
}

# expect_exit <description> <code> <command...>: runs the command in the scratch app and records its output in $log.
expect_exit() {
    local description="$1" want="$2" got=0
    shift 2
    (cd "$app" && "$@") >"$log" 2>&1 || got=$?
    if [[ "$got" == "$want" ]]; then
        ok "$description"
    else
        echo "expected exit $want, got $got" >>"$log"
        not_ok "$description"
    fi
}

# expect_log <description> <pattern>: the last command's output matches the extended regex.
expect_log() {
    if grep -qE -- "$2" "$log"; then
        ok "$1"
    else
        echo "no match for: $2" >>"$log"
        not_ok "$1"
    fi
}

commit_all() {
    git -C "$app" add -A
    git -C "$app" commit -qm "$1"
}

setup_app() {
    mkdir -p "$app"
    rsync -a --exclude .build --exclude .swiftpm "$root/fixtures/sample-app/" "$app/"
    git -C "$app" init -q -b main
    git -C "$app" config user.name "fleet self-test"
    git -C "$app" config user.email "self-test@fleet.invalid"
    commit_all "Sample app"
}

test_fixture() {
    expect_exit "fixture: behaviours pass" 0 swift run -q app test all
    expect_exit "fixture: vectors fail on the planted vector" 1 swift run -q app vectors all
    expect_log "fixture: the planted failure is floor/stops-at-zero" '"vector":"stops-at-zero"'
    expect_log "fixture: the counter vectors pass" '"failures":\[\],"name":"counter"'
}

test_dispatcher() {
    expect_exit "fleet: help exits 0" 0 "$fleet" help
    expect_exit "fleet: an unknown gate exits 2" 2 "$fleet" gate no-such-gate
    expect_exit "fleet: run is not available before C8" 2 "$fleet" run feature
}

setup_app
test_fixture
test_dispatcher

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" == 0 ]]
