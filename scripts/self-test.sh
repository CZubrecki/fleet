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

# expect_evidence <description> <evidence.json> <jq filter>: the filter must print true.
expect_evidence() {
    if [[ -f "$2" ]] && [[ "$(jq "$3" "$2")" == "true" ]]; then
        ok "$1"
    else
        { echo "filter: $3"; cat "$2" 2>/dev/null || echo "no evidence at $2"; } >"$log"
        not_ok "$1"
    fi
}

commit_all() {
    git -C "$app" add -A
    git -C "$app" commit -qm "$1"
}

init_repo() {
    git -C "$1" init -q -b main
    git -C "$1" config user.name "fleet self-test"
    git -C "$1" config user.email "self-test@fleet.invalid"
    git -C "$1" add -A
    git -C "$1" commit -qm "Initial"
}

setup_app() {
    mkdir -p "$app"
    rsync -a --exclude .build --exclude .swiftpm --exclude .fleet/out "$root/fixtures/sample-app/" "$app/"
    init_repo "$app"
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

test_behaviour_on_sample_app() {
    local evidence="$app/.fleet/out/behaviour/evidence.json" head
    head="$(git -C "$app" rev-parse HEAD)"

    expect_exit "behaviour: fails on the planted vector" 1 "$fleet" gate behaviour --repo . --sha HEAD
    expect_evidence "behaviour: evidence is bound to the full HEAD sha" "$evidence" ".sha == \"$head\" and .dirty == false"
    expect_evidence "behaviour: the only finding is the planted vector" "$evidence" \
        '.verdict == "fail" and ([.findings[].id] == ["vectors:floor:stops-at-zero"])'
    expect_evidence "behaviour: the finding says what was expected" "$evidence" \
        '.findings[0].note == "input decrement: expected 0, got -1" and .findings[0].evidence == "behaviour/vectors.log"'
    expect_exit "behaviour: the cited log sits beside the evidence" 0 grep -q stops-at-zero "$app/.fleet/out/behaviour/vectors.log"

    sed -i '' 's/state.count -= 1/state.count = max(0, state.count - 1)/' "$app/Sources/SampleCore/Counter.swift"
    commit_all "Clamp decrement at zero"
    expect_exit "behaviour: passes once the planted bug is fixed" 0 "$fleet" gate behaviour --repo . --sha HEAD
    expect_evidence "behaviour: a pass has no findings" "$evidence" '.verdict == "pass" and .findings == [] and .error == null'

    expect_exit "behaviour: a sha other than HEAD cannot run" 2 "$fleet" gate behaviour --repo . --sha HEAD~1
    expect_evidence "behaviour: a stale sha is recorded as an error" "$evidence" '.verdict == "error" and (.error | test("check out"))'

    echo "import AppKit" >"$app/Sources/SampleCore/Leak.swift"
    commit_all "Import AppKit into Core"
    expect_exit "behaviour: fails when the architecture check fails" 1 "$fleet" gate behaviour --repo . --sha HEAD
    expect_evidence "behaviour: the architecture finding carries the check's output" "$evidence" \
        '[.findings[].id] == ["architecture"] and (.findings[0].note | test("Rule 1"))'
    git -C "$app" rm -q "Sources/SampleCore/Leak.swift"
    commit_all "Remove the AppKit import"

    for _ in $(seq 400); do echo "// filler"; done >"$app/Sources/SampleCore/Long.swift"
    commit_all "Add a 400-line file"
    expect_exit "behaviour: fails on a file at the line limit" 1 "$fleet" gate behaviour --repo . --sha HEAD
    expect_evidence "behaviour: the long file is named" "$evidence" '[.findings[].id] == ["long-file:Sources/SampleCore/Long.swift"]'
    git -C "$app" rm -q "Sources/SampleCore/Long.swift"
    commit_all "Remove the long file"
}

test_behaviour_contract() {
    local repo="$work/contract" evidence
    mkdir -p "$repo"
    printf 'test: "echo booting; echo broken >&2; exit 3"\n' >"$repo/.fleet.yaml"
    init_repo "$repo"
    evidence="$work/contract-out/behaviour/evidence.json"

    expect_exit "contract: --sha is required" 2 "$fleet" gate behaviour --repo "$repo"
    expect_exit "contract: unknown arguments cannot run" 2 "$fleet" gate behaviour --repo "$repo" --sha HEAD --bogus
    expect_exit "contract: a failing command without result lines fails" 1 \
        "$fleet" gate behaviour --repo "$repo" --sha HEAD --out "$work/contract-out"
    expect_evidence "contract: --out is honoured and the finding keeps the output tail" "$evidence" \
        '[.findings[].id] == ["test"] and (.findings[0].note | test("exit 3: booting\nbroken"))'

    echo "local edit" >"$repo/notes.txt"
    expect_exit "contract: a dirty tree still runs" 1 "$fleet" gate behaviour --repo "$repo" --sha HEAD --out "$work/contract-out"
    expect_evidence "contract: a dirty tree is recorded" "$evidence" '.dirty == true'
    rm "$repo/notes.txt"

    printf 'test: "true"\narchitecture_check: scripts/missing.sh\n' >"$repo/.fleet.yaml"
    git -C "$repo" commit -qam "Point at a missing check"
    expect_exit "contract: a missing architecture check cannot run" 2 \
        "$fleet" gate behaviour --repo "$repo" --sha HEAD --out "$work/contract-out"

    git -C "$repo" rm -q .fleet.yaml
    git -C "$repo" commit -qm "Remove config"
    expect_exit "contract: no .fleet.yaml cannot run" 2 "$fleet" gate behaviour --repo "$repo" --sha HEAD --out "$work/contract-out"
    expect_evidence "contract: the missing config is the recorded error" "$evidence" '.verdict == "error" and (.error | test("no .fleet.yaml"))'
}

setup_app
test_fixture
test_dispatcher
test_behaviour_on_sample_app
test_behaviour_contract

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" == 0 ]]
