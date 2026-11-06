# Status

Where Phase 2 stands, and what the next session needs to pick it up.
The plan is `docs/prd/phase-2-gate-loop.md`; the per-checkpoint record is `CHANGELOG.md`.

Last updated: 2026-11-06.

## Done

| # | Checkpoint | PR | State |
| --- | --- | --- | --- |
| C1 | Repo skeleton, sample app, self-test, CI | #1 | Merged |
| C2 | `lib/` and `behaviour.sh` | #2 | Merged |
| C3 | `plan-approve.sh` and the approved-plan guard | #3 | Merged |

CI on `main` is green: shellcheck clean, self-test 51/51 on the macos-15 runner with system bash 3.2 and system Ruby.
All checkpoint branches are merged and deleted; `main` is the only branch.

## Next: C4

`agents/models.yaml` and `agents/gates/lib/model.sh`, per the "Model slots and the vision benchmark" section of the PRD.

- One function, `call_slot <slot> <prompt.md> <inputs...>`, that returns JSON.
- No script names a model; slots map to provider, model id and temperature in `models.yaml`.
- Cost guard: `max_usd_per_run` per slot, and `model.sh` refuses (exit 2) a call whose estimated tokens exceed it.
- Evidence records `prompt_sha` and `model` (the fields already exist in `gate_write_evidence`, fed by `GATE_PROMPT_SHA` and `GATE_MODEL`).
- A `smoke` slot test in the self-test with a fixed tiny prompt.

Questions to settle at the start of C4:

- Which provider and CLI or API `call_slot` uses for each slot, and where credentials come from (scripts own credentials).
- How the self-test's `smoke` case behaves in CI without a key: skip with a clear message, or require a repo secret.
- How tokens are estimated for the cost guard before a call is made.

## Decisions owed before C5

C5 wires `review.sh` and the gates into Vespers, so these must be settled first.

- **Vespers PRs without a `plan.md`.** As built, `behaviour.sh` exits 2 when there is no approved plan, so every such PR is blocked. Options: require a plan on every PR, make the plan requirement a `.fleet.yaml` key, or skip the guard when `plan.md` is absent.
- **Vespers `.gitignore`** needs `.fleet/out/` so gate evidence never shows as a dirty tree.
- **The approval record is forgeable.** `.fleet/approved-plan.sha` is a plain file; the gate cannot tell whether Connor or an agent wrote it. `AGENTS.md` forbids agents writing it, and `RISK.yaml` marks `.fleet/**` high, but nothing enforces it. A signed commit or a GitHub-side check is the likely fix if this matters.

## Known deviations from the PRD

- C1's "`self-test.yml` running an empty gate" became a self-test that proves the fixture's planted failure, which is a stronger check.
- The vector finding id fix (`<step>:<report>:<vector>@<input>`) landed in the C3 commit rather than C2.
- `main` carries an empty "Trigger CI" commit from debugging; GitHub did not register the workflow until the first push to `main`, so the C1-C3 PRs merged without PR checks. PR checks should run from now on.

## Environment notes

- YAML goes only through `yaml_to_json` in `agents/gates/lib/yaml.sh` (Ruby stdlib); swapping the reader is one line.
- jq is checked at the top of `lib/common.sh` with a clear error.
- The macos-15 runner's default `ruby` is Homebrew 3.3; CI puts `/bin:/usr/bin` first so the self-test uses system bash and Ruby.
- A trial of `behaviour.sh` against a Vespers clone, using the PRD's `.fleet.yaml`, passed in about 42s and reported a planted vector error correctly.
