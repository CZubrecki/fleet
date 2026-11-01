# shellcheck shell=bash
# The approved-plan record: .fleet/approved-plan.sha holds "<sha256>  <plan path>" for the plan as committed.

PLAN_RECORD=".fleet/approved-plan.sha"
PLAN_PATH=""
PLAN_HASH=""
PLAN_APPROVED_HASH=""
PLAN_STATE=""

sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d ' ' -f 1
    else
        sha256sum | cut -d ' ' -f 1
    fi
}

# plan_load: sets PLAN_STATE to approved, unapproved, drifted, or missing for the plan committed at SHA.
plan_load() {
    PLAN_PATH="$(config_get .plan plan.md)"
    PLAN_HASH=""
    PLAN_APPROVED_HASH=""
    if ! git_show "$REPO" "$SHA" "$PLAN_PATH" >/dev/null; then
        PLAN_STATE=missing
        return
    fi
    PLAN_HASH="$(git_show "$REPO" "$SHA" "$PLAN_PATH" | sha256)"
    if ! git_show "$REPO" "$SHA" "$PLAN_RECORD" >/dev/null; then
        PLAN_STATE=unapproved
        return
    fi
    PLAN_APPROVED_HASH="$(git_show "$REPO" "$SHA" "$PLAN_RECORD" | awk 'NR == 1 { print $1 }')"
    if [[ "$PLAN_APPROVED_HASH" == "$PLAN_HASH" ]]; then
        PLAN_STATE=approved
    else
        PLAN_STATE=drifted
    fi
}

plan_problem() {
    case "$PLAN_STATE" in
        missing) echo "no $PLAN_PATH at $SHA" ;;
        unapproved) echo "$PLAN_PATH has not been approved; run plan-approve.sh --approve" ;;
        drifted) echo "$PLAN_PATH changed after approval (approved $PLAN_APPROVED_HASH, now $PLAN_HASH)" ;;
    esac
}

# plan_require_approved: the guard every later gate runs; a plan that is not approved means the gate cannot run.
plan_require_approved() {
    plan_load
    [[ "$PLAN_STATE" == approved ]] || gate_error "$(plan_problem)"
}
