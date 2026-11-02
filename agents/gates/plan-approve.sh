#!/usr/bin/env bash
# Gate 0: --approve records the hash of the committed plan in its own commit; --check (the default) passes
# while the plan at --sha still matches that record.
set -euo pipefail
# shellcheck source=agents/gates/lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

gate_init plan-approve "$@"
mode=check
for arg in ${GATE_ARGS[@]+"${GATE_ARGS[@]}"}; do
    case "$arg" in
        --check) mode=check ;;
        --approve) mode=approve ;;
        *) gate_error "unknown argument: $arg" ;;
    esac
done
gate_load_config
plan_load

if [[ "$mode" == approve ]]; then
    [[ "$PLAN_STATE" != missing ]] || gate_error "$(plan_problem)"
    git -C "$REPO" diff --quiet HEAD -- "$PLAN_PATH" || gate_error "$PLAN_PATH has uncommitted changes; commit the plan you are approving"
    if [[ "$PLAN_STATE" != approved ]]; then
        mkdir -p "$REPO/.fleet"
        printf '%s  %s\n' "$PLAN_HASH" "$PLAN_PATH" >"$REPO/$PLAN_RECORD"
        git -C "$REPO" add -- "$PLAN_RECORD"
        git -C "$REPO" commit -q --only -m "Approve $PLAN_PATH (${PLAN_HASH:0:12})" -- "$PLAN_RECORD" \
            || gate_error "could not commit $PLAN_RECORD"
        SHA="$(git_head "$REPO")"
        plan_load
    fi
fi

case "$PLAN_STATE" in
    approved) ;;
    missing) finding plan-missing high "$PLAN_PATH" "" "$(plan_problem)" ;;
    unapproved) finding plan-unapproved high "$PLAN_PATH" "$PLAN_RECORD" "$(plan_problem)" ;;
    drifted) finding plan-drifted high "$PLAN_PATH" "$PLAN_RECORD" "$(plan_problem)" ;;
esac
gate_finish
