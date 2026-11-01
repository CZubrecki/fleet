# shellcheck shell=bash
# Sourced first by every gate: argument parsing, the SHA binding, config, findings, and the evidence file.

if ! command -v jq >/dev/null 2>&1; then
    echo "fleet: jq is required (macOS 15+ ships it at /usr/bin/jq; otherwise 'brew install jq')." >&2
    exit 2
fi

FLEET_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLEET_ROOT="$(cd "$FLEET_LIB/../../.." && pwd)"
# shellcheck source=agents/gates/lib/json.sh
. "$FLEET_LIB/json.sh"
# shellcheck source=agents/gates/lib/git.sh
. "$FLEET_LIB/git.sh"
# shellcheck source=agents/gates/lib/yaml.sh
. "$FLEET_LIB/yaml.sh"

GATE=""
REPO=""
SHA=""
OUT=""
GATE_DIR=""
GATE_ARGS=()
GATE_STARTED=""
GATE_STARTED_S=0
GATE_DIRTY=false
FLEET_CONFIG="null"

die() {
    echo "fleet $GATE: $*" >&2
    exit 2
}

# gate_init <gate> "$@": parses --repo, --sha and --out, leaves anything else in GATE_ARGS, binds the run to
# the checked-out commit, and clears this gate's evidence folder.
gate_init() {
    GATE="$1"
    shift
    local repo="" sha="" out=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) repo="${2:-}"; shift 2 || die "--repo needs a path" ;;
            --sha) sha="${2:-}"; shift 2 || die "--sha needs a commit" ;;
            --out) out="${2:-}"; shift 2 || die "--out needs a directory" ;;
            *) GATE_ARGS+=("$1"); shift ;;
        esac
    done
    [[ -n "$repo" ]] || die "--repo is required"
    [[ -n "$sha" ]] || die "--sha is required"
    [[ -d "$repo" ]] || die "no such repo: $repo"
    REPO="$(cd "$repo" && pwd)"
    git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $REPO"

    out="${out:-$REPO/.fleet/out}"
    mkdir -p "$out" || die "cannot create $out"
    OUT="$(cd "$out" && pwd)"
    GATE_DIR="$OUT/$GATE"
    rm -rf "$GATE_DIR"
    mkdir -p "$GATE_DIR"
    : >"$GATE_DIR/.findings"
    GATE_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    GATE_STARTED_S="$(date +%s)"

    SHA="$(git_resolve "$REPO" "$sha")" || { SHA="$sha"; gate_error "unknown commit: $sha"; }
    local head
    head="$(git_head "$REPO")" || gate_error "repo has no commits"
    [[ "$head" == "$SHA" ]] || gate_error "HEAD is $head, not $SHA; check out the commit under review first"

    local excluded=(.fleet/out)
    case "$OUT/" in
        "$REPO"/*) excluded+=("${OUT#"$REPO"/}") ;;
    esac
    if git_dirty "$REPO" "${excluded[@]}"; then
        GATE_DIRTY=true
    fi
}

# gate_load_config: reads <repo>/.fleet.yaml into FLEET_CONFIG.
gate_load_config() {
    local file="$REPO/.fleet.yaml"
    [[ -f "$file" ]] || gate_error "no .fleet.yaml in $REPO"
    FLEET_CONFIG="$(yaml_to_json "$file" 2>"$GATE_DIR/config.err")" || gate_error "cannot read .fleet.yaml: $(cat "$GATE_DIR/config.err")"
    rm -f "$GATE_DIR/config.err"
    [[ "$(jq -r 'type' <<<"$FLEET_CONFIG")" == "object" ]] || gate_error ".fleet.yaml is not a mapping"
}

# config_get <jq path> [default]: prints a scalar from .fleet.yaml, or the default when it is absent.
config_get() {
    jq -r --arg default "${2:-}" "$1 // \$default | tostring" <<<"$FLEET_CONFIG"
}

# finding <id> <severity> <where> <evidence> <note>
finding() {
    json_finding "$@" >>"$GATE_DIR/.findings"
}

gate_has_findings() {
    [[ -s "$GATE_DIR/.findings" ]]
}

gate_write_evidence() {
    local verdict="$1" error="${2:-}" fleet_sha
    fleet_sha="$(git_head "$FLEET_ROOT" 2>/dev/null || true)"
    jq -s \
        --arg gate "$GATE" \
        --arg sha "$SHA" \
        --arg fleet_sha "$fleet_sha" \
        --argjson dirty "$GATE_DIRTY" \
        --argjson prompt_sha "${GATE_PROMPT_SHA:-null}" \
        --argjson model "${GATE_MODEL:-null}" \
        --arg verdict "$verdict" \
        --arg error "$error" \
        --arg started "$GATE_STARTED" \
        --argjson duration "$(($(date +%s) - GATE_STARTED_S))" \
        '{
            gate: $gate,
            sha: $sha,
            fleet_sha: (if $fleet_sha == "" then null else $fleet_sha end),
            dirty: $dirty,
            prompt_sha: $prompt_sha,
            model: $model,
            verdict: $verdict,
            error: (if $error == "" then null else $error end),
            findings: .,
            started: $started,
            duration_s: $duration
        }' "$GATE_DIR/.findings" >"$GATE_DIR/evidence.json"
    rm -f "$GATE_DIR/.findings"
}

# gate_error <message>: records a could-not-run verdict and exits 2.
gate_error() {
    echo "fleet $GATE: $1" >&2
    gate_write_evidence error "$1"
    exit 2
}

# gate_finish: passes when no finding was recorded, otherwise fails.
gate_finish() {
    if gate_has_findings; then
        gate_write_evidence fail
        echo "fleet $GATE: fail ($(jq '.findings | length' "$GATE_DIR/evidence.json") findings, $GATE_DIR/evidence.json)" >&2
        exit 1
    fi
    gate_write_evidence pass
    echo "fleet $GATE: pass ($GATE_DIR/evidence.json)" >&2
    exit 0
}
