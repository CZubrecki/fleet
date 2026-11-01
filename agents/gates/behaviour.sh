#!/usr/bin/env bash
# Gate 1: runs the app's behaviour suite, vectors and architecture check from .fleet.yaml, and the file length rule.
set -euo pipefail
# shellcheck source=agents/gates/lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

gate_init behaviour "$@"
[[ ${#GATE_ARGS[@]} -eq 0 ]] || gate_error "unknown argument: ${GATE_ARGS[0]}"
gate_load_config
plan_require_approved

# run_step <step> <command>: runs one .fleet.yaml command in the repo and records a finding per failed result.
run_step() {
    local step="$1" command="$2" log="$GATE_DIR/$1.log" status=0 before
    before="$(wc -l <"$GATE_DIR/.findings")"
    echo "fleet behaviour: $step: $command" >&2
    (cd "$REPO" && bash -c "$command") >"$log" 2>&1 || status=$?
    json_result_findings "$step" "$GATE/$step.log" <"$log" >>"$GATE_DIR/.findings"
    if [[ "$status" != 0 && "$(wc -l <"$GATE_DIR/.findings")" == "$before" ]]; then
        finding "$step" high "$step" "$GATE/$step.log" "exit $status: $(tail -n 20 "$log")"
    fi
}

test_command="$(config_get .test)"
[[ -n "$test_command" ]] || gate_error ".fleet.yaml has no test command"
run_step test "$test_command"

vectors_command="$(config_get .vectors)"
if [[ -n "$vectors_command" ]]; then
    run_step vectors "$vectors_command"
fi

architecture_check="$(config_get .architecture_check)"
if [[ -n "$architecture_check" ]]; then
    [[ -f "$REPO/$architecture_check" ]] || gate_error "architecture_check $architecture_check does not exist"
    run_step architecture "$architecture_check"
fi

line_limit="$(config_get .file_line_limit 400)"
[[ "$line_limit" =~ ^[0-9]+$ ]] || gate_error "file_line_limit must be a number, not $line_limit"
source_glob="$(config_get .source_glob '*.swift')"
while IFS= read -r -d '' path; do
    [[ -f "$REPO/$path" ]] || continue
    lines="$(wc -l <"$REPO/$path" | tr -d ' ')"
    if (( lines >= line_limit )); then
        finding "long-file:$path" high "$path" "$path" "$lines lines; source files stay under $line_limit"
    fi
done < <(git -C "$REPO" ls-files -z -- "$source_glob")

gate_finish
