# Fleet Phase 2: PRD for the Gate Loop

2026-11-01 · Connor Zubrecki
Living copy: https://claude.ai/artifact/4Vb3587RadwoYS6gW4XJv1 (this file is the snapshot committed to the repo; the link wins if they differ)

## Summary

**North star.** Fleet exists so Connor can spin up a new iOS app quickly and have it built and maintained mostly by AI. Every phase is judged by one question: does it make the next app cheaper to start and cheaper to keep shipping? Marketing and distribution automation come later, once apps themselves are fast to build. A second rule: delay buying the Mac mini as long as possible; every Mac-shaped need gets a hosted substitute first. Phase 2 passes both tests because the gates are written once in `fleet` and cost a new app one `.fleet.yaml` file.

Phase 2 turns the gate loop from a thing Connor does by hand into four scripts in a new `fleet` repo that any app's CI can call. Today every Vespers checkpoint ends the same way: the agent says "done", Connor reads the diff, runs the CLI, squints at screenshots, and decides. Phase 2 makes the first three of those decisions automatic and leaves him only the fourth, a PR that has already passed behaviour, UI review and two adversarial reviewers.

The repo holds harness and knowledge only. Router stays its own tagged package and Vespers stays in its own repo; both consume fleet by path. Nothing in Phase 2 needs the Mac mini, a database, or a server. It runs on the laptop Connor already has, against the Vespers UI work the agent is building right now, so the gates get real traffic from day one.

Done means: a Vespers PR opens with four green checks (`plan-approve`, `behaviour`, `ui-review`, `review`), each check's evidence attached as a JSON artifact bound to the commit SHA, and a line comment Connor leaves on that PR lands in `agents/memory/vespers/feedback.md` without him copying it.

**And the deliverable is Vespers, not the harness.** Phase 2 ends with the rewritten Vespers on TestFlight and then the App Store, every PR on the way having gone through the four gates. The harness is the means; a shipped app is the proof, and the real measure is what comes after: a new Vespers feature should go from a task file to the App Store with AI doing the building and Connor doing one review, in days rather than weekends. A ninth checkpoint, C9 Ship, is added below for that: a `release.yaml` profile that runs the existing Fastlane lanes (bump, build, upload) only when the four checks are green on `main`, so the release is the last gate and not a separate ritual.

## Where we are

Phases 0 and 1 of the design plan are done: the headless core exists and a CLI drives it. What is still Connor by hand is every gate.

| Piece | State | Who does it today |
| --- | --- | --- |
| Router 1.0.0 (tagged package, 98% coverage) | Done | Nobody; it is a dependency |
| VespersCore + Features + TestKit + CLI (`app test all`, `app vectors all`) | Done, CI green | CI runs it; Connor reads the result |
| `scripts/check-architecture.sh`, `docs/architecture.md`, `AGENTS.md` in Vespers | Done | Connor, when he remembers |
| Vespers UI (11 checkpoints vs the Paper design) | Agent building now | Connor compares screenshots to Paper by eye |
| Plan approval before implementation | Chat-only | Connor says "go" in a message; nothing records it |
| Adversarial code review | None | Connor reads the diff |
| Feedback from PR comments into agent context | None | Connor re-explains the same rule each session |
| Model choice per role | Whatever the agent client defaults to | Nobody |

The pattern in the right column is the Phase 2 scope. Each row is a manual step that repeats per checkpoint; the UI work alone has eleven, and eSIM and Totem will multiply it. Fleet exists to make those rows read "a script".

## The fleet repo

`fleet` is a GitHub repo (`CZubrecki/fleet`) that holds the harness and the knowledge, and no app code. Checked out as a sibling of the app repos: `~/Development/fleet` beside `~/Development/Vespers`.

```
fleet/
  AGENTS.md                      how an agent working IN fleet behaves
  RISK.yaml                      path globs → High / Medium / Low tier
  agents/
    gates/
      plan-approve.sh            Gate 0: hash the plan, record approval
      behaviour.sh               Gate 1: run the app's CLI tests + vectors
      ui-review.sh               Gate 2: screenshots vs reference, vision model
      review.sh                  Gate 3: two isolated reviewers + judge
      lib/                       shared bash: json.sh, git.sh, model.sh
    prompts/
      planner.md  implementer.md  vision_reviewer.md
      code_reviewer_a.md  code_reviewer_b.md  judge.md
    skills/                      reusable agent skills (swift-cli-harness, paper-export, stacked-pr)
    profiles/
      feature.yaml               plan → implement → 4 gates → stacked PR
      pr-review.yaml             gates 1-3 only, on an existing PR
      release.yaml               Fastlane lanes, gated on 4 green checks on main
    models.yaml                  slot → provider/model/temperature
    memory/
      vespers/feedback.md        rules distilled from Connor's PR comments
      vespers/decisions.md       closed questions (copied from the PRDs)
  ops-cli/                       stub: `fleet` bash entrypoint that dispatches to gates/
  docs/
    architecture.md              fleet's own architecture
    prd/                         snapshots of the PRDs (this file)
    knowledge/vespers/           links to PRDs, Paper file id, artboard map
  fixtures/
    sample-app/                  200-line Swift package: one Feature, one passing + one failing vector
    ui-bench/                    12 screenshot/artboard pairs for choosing the vision model
  .github/workflows/self-test.yml  runs each gate against fixtures/sample-app
```

Rules for what goes in:

- **Scripts are deterministic and own the side effects.** Only bash (or a small Swift CLI later) touches git, credentials, GitHub, or the ledger. Agents produce JSON and prose; scripts decide.
- **Prompts are files, not strings in scripts.** Every prompt in `agents/prompts/` is versioned; a gate's evidence records which prompt SHA it ran.
- **Memory is per app, knowledge is per app, gates are shared.** `agents/memory/<app>/` and `docs/knowledge/<app>/` grow one folder per app; `agents/gates/` never branches on app name. An app-specific need becomes a flag or a config file in the app repo (`.fleet.yaml`).
- **No app code, no Router.** Router stays a tagged package consumed by version. Vespers stays in its repo. Fleet is what both of them call, not where they live.
- **Fleet tests itself.** `self-test.yml` runs every gate against `fixtures/sample-app/`, so a broken gate is caught in fleet and not in Vespers.

## The four gate scripts

The loop: Gate 0 Plan (hash approved) → Implement (agent, stacked branch) → Gate 1 Behaviour (app test + vectors) → Gate 2 UI review (shots vs Paper, vision) → Gate 3 Review (2 reviewers + judge) → Gate 4 Connor (stacked PR, line comments) → Feedback memory (rules into next run). A failed gate sends its findings back to the implementer, bounded (max 2 loops); Connor's line comments feed the memory that the next run reads.

Every gate has the same shape: `agents/gates/<gate>.sh --repo <path> --sha <sha> [--out <dir>]`, exit 0 pass / 1 fail / 2 could-not-run, and one `evidence.json` written to `<out>/<gate>/`. CI uploads that folder as the check's artifact. Nothing a gate writes is trusted unless `evidence.json.sha` equals the commit it ran on, which is how a stale pass is caught after a force-push.

```json
{
  "gate": "ui-review",
  "sha": "3f1c0a2",
  "prompt_sha": "a91e…",
  "model": {"slot": "vision_reviewer", "id": "…"},
  "verdict": "fail",
  "findings": [{"id": "today-cta-color", "severity": "high", "where": "TodayView", "evidence": "shots/today-returning.png", "note": "CTA is #626B45, Paper HY-0 shows #A74E3D in Pentecost"}],
  "started": "2026-11-01T14:02:11Z", "duration_s": 84
}
```

| Gate | Script | Input | What it does | Pass when |
| --- | --- | --- | --- | --- |
| 0 Plan | `plan-approve.sh` | `plan.md` in the PR branch | SHA-256 of the plan; writes `.fleet/approved-plan.sha` when Connor runs it with `--approve`; later gates refuse if the plan file no longer matches | Hash recorded and unchanged |
| 1 Behaviour | `behaviour.sh` | app repo | Reads `.fleet.yaml` for the test command (Vespers: `swift run app test all && swift run app vectors all`), runs `scripts/check-architecture.sh` if present, parses the result into findings | Exit 0 from both, no file over 400 lines |
| 2 UI review | `ui-review.sh` | `.fleet.yaml` scenario → artboard map | For each row: boot the simulator, load the scenario via `remote`, `remote shot`, export the Paper artboard PNG, send both to the `vision_reviewer` slot with `vision_reviewer.md`; collects findings | No `high` findings; `medium` allowed with a note |
| 3 Code review | `review.sh` | diff of `sha` vs base | Two isolated reviewers (`code_reviewer_a`, `_b`) each get the diff, `architecture.md`, `AGENTS.md`, `memory/<app>/feedback.md`, and nothing else; the `judge` slot reconciles into one findings list | No `high`; each `medium` has an agreed-by-both flag or a judge ruling |

Gate 4 is not a script. It is the stacked PR itself: `profiles/feature.yaml` ends by opening the PR with the four evidence files linked in the body, and `review.sh --post` turns each `high`/`medium` finding into a line comment so Connor sees what the machines saw.

Details that matter:

- **Gate 0 records, it does not block the agent.** The implementer can start before approval; `behaviour.sh` and later simply refuse with exit 2 until `approved-plan.sha` matches. This keeps Connor out of the critical path when he is at work.
- **Gate 2 takes the reference from Paper, not from a committed PNG.** `paper-export` skill calls the Paper MCP `export` on the artboard id in the map; the PNG is cached by Paper file version so a design change invalidates the comparison. Until the Paper export is scripted, the fallback is the `design/reference/*.png` folder Connor exports by hand.
- **Gate 2's judge is the same vision slot run a second time with the two findings lists.** Running it once gives one opinion; a reviewer that disagrees with itself across two runs is flagged `unstable` and the finding dropped to `medium`.
- **Gate 3 reviewers never see each other.** Separate processes, separate prompts, the second with a different emphasis (A: correctness and architecture rules; B: tests, naming, and the feedback memory). Agreement is signal, not a majority vote.
- **Every gate is re-runnable and idempotent.** Same SHA in, same evidence file out, overwriting; no gate appends to anything but the log.

## Model slots and the vision benchmark

No script names a model. Each names a slot, and `agents/models.yaml` maps the slot to a provider, model id and temperature. Swapping the vision reviewer is a one-line change and the evidence files record which model produced each verdict, so a regression is traceable.

| Slot | Used by | Starting choice | Why |
| --- | --- | --- | --- |
| `planner` | feature profile, step 1 | strongest reasoning model available | Plans are cheap to generate and expensive to get wrong |
| `implementer` | feature profile, step 2 | the agent client Connor already uses | Already tuned to his Swift and the Vespers AGENTS.md |
| `vision_reviewer` | `ui-review.sh` | **decided by the benchmark below** | Screenshot-vs-mockup judgement varies a lot by model |
| `code_reviewer_a` | `review.sh` | a different vendor from `implementer` | Cross-model review catches the implementer's blind spots |
| `code_reviewer_b` | `review.sh` | same vendor as `implementer`, different prompt | Cheap second opinion that knows the idioms |
| `judge` | `review.sh`, `ui-review.sh` | small, fast, temperature 0 | It only reconciles two lists; it never reads code |
| `bulk_reader` | shunt hook (Phase 3) | cheapest model with a long context | Summarises large files so the implementer never reads them raw |

The benchmark is a fixture, not an opinion. Before `ui-review.sh` is trusted, `fixtures/ui-bench/` holds 12 pairs: the Paper export for Today, Session, Journey and Settings, each paired with three screenshots. One matches, one has a planted colour or spacing error (CTA in heritage-olive where the artboard says Pentecost red; 24pt padding where the token is 32), and one has a planted content error (wrong mystery name, a missing milestone badge). Each candidate model runs the twelve and is scored on: planted errors caught, false positives on the matching shots, and consistency across two runs. The slot goes to the model with zero false positives on the matching shots and the most planted errors caught; ties go to the cheaper one. The scores are committed to `fixtures/ui-bench/results.md` so the choice can be re-run when a new model ships.

Cost guard: `models.yaml` carries a `max_usd_per_run` per slot and `lib/model.sh` refuses a call whose estimated tokens exceed it. A runaway review loop fails with exit 2 instead of a surprise invoice.

## Feedback memory

A PR comment Connor writes once should never need writing twice. Today he re-explains the same rule ("child views, not computed properties"; "no `Date()` in Core") to each new agent session. Phase 2 closes that loop in three steps, all scripted.

1. **Capture.** A GitHub Actions workflow in the app repo (`.github/workflows/fleet-feedback.yml`) fires on `pull_request_review_comment`. If the author is Connor, it appends one entry to `agents/memory/<app>/feedback.md` in fleet via a PR: date, PR number, file and line, his comment verbatim, and the diff hunk it was on. The entry starts tagged `raw`.
2. **Distil.** `agents/gates/lib/distil.sh`, run nightly or by hand, hands every `raw` entry to the `judge` slot with `distil.md`, which rewrites each as one imperative rule under 25 words, or marks it `one-off` if it was about that PR only. Rules move to the `## Rules` section at the top of the file; `one-off` entries stay below as history. Connor reviews the distil PR; it is the only place he edits memory.
3. **Apply.** `code_reviewer_b` and the implementer prompt both include `## Rules` from `feedback.md`. Nothing else in the loop reads it, so the file stays small and the rules stay the implementer's and reviewer's, not the planner's.

A rule that keeps catching the same finding across three PRs is a candidate for `docs/architecture.md` in the app repo or for a check in `check-architecture.sh`; `distil.sh` prints those candidates at the end of its run. Promoting a rule into a script is how memory shrinks, which is the goal: the best feedback file is one most of whose rules have become tests.

The memory file format, so the agents and the script agree:

```markdown
## Rules
- R-004 Child SwiftUI views are their own `struct`, never a computed `var body` helper. (PR #41, 2026-11-03)
- R-005 `HistoryStore` writes go through `merged(with:)`; never overwrite a snapshot. (PR #44, 2026-11-05)

## History
- 2026-11-05 raw PR #44 Vespers/Source/.../HistoryStore.swift:88 — "this will clobber the CloudKit copy" → R-005
```

## The profiles

A profile is a YAML file that names the steps, the slot each step uses, and which gates must pass before the next step. Phase 2 ships three. `ops-cli/fleet run <profile> --repo <path> --task <file>` reads one and executes it; in Phase 2 that runner is bash, and a step that needs an agent shells out to the agent client with the prompt file and the task.

```yaml
# agents/profiles/feature.yaml
name: feature
steps:
  - id: plan
    slot: planner
    prompt: prompts/planner.md
    inputs: [task.md, docs/architecture.md, AGENTS.md, memory/<app>/feedback.md#Rules]
    output: plan.md
  - id: approve
    gate: plan-approve          # blocks here until --approve is run
  - id: implement
    slot: implementer
    prompt: prompts/implementer.md
    inputs: [plan.md, memory/<app>/feedback.md#Rules]
    branch: feat/<task-slug>     # stacked on the current branch
    until: gate behaviour passes, max 3 attempts
  - id: gates
    run: [behaviour, ui-review, review]
    on_fail: back to implement with findings, max 2 loops
  - id: pr
    run: lib/stacked-pr.sh      # opens the PR, links evidence, posts line comments
```

`pr-review.yaml` is the same file from `gates` down, pointed at an existing PR's head SHA. It is what the car-wash contract gets: no planner, no implementer, just the three gates and line comments, which is the cheapest useful thing fleet can do for a codebase it does not own.

`release.yaml` (C9) wraps the app's existing Fastlane lanes (bump, build, TestFlight, App Store) and refuses to run unless the four checks are green on `main` at the SHA being released.

Two constraints on profiles:

- **Loops are bounded in the file, not in the agent.** `max 3 attempts`, `max 2 loops`. When a bound is hit the profile stops with exit 2 and a `blocked.md` saying what failed last; it never asks the agent to "try harder".
- **A profile step never calls another profile.** Composition is by CI (one workflow per profile), so the trace of what ran is one file, one log.

## How Vespers consumes it

Vespers adds one file and one workflow, and moves nothing. The app repo stays the source of truth for its own tests, architecture doc and agent rules; fleet only needs to know where they are.

`.fleet.yaml` at the Vespers root:

```yaml
app: vespers
fleet: ../fleet                     # local sibling; CI checks out CZubrecki/fleet@main here
test: swift run --package-path Packages/VespersCLI app test all
vectors: swift run --package-path Packages/VespersCLI app vectors all
architecture_check: scripts/check-architecture.sh
architecture_doc: docs/architecture.md
agents_doc: AGENTS.md
ui:
  scheme: Vespers
  simulator: "iPhone 16"
  paper_file: 01M644M89YTQVP08C9YYMTXQ5X
  scenarios:
    - { scenario: today-returning,  artboard: HY-0 }
    - { scenario: session-decade-2, artboard: 2U-0 }
    - { scenario: journey-week,     artboard: M2-0 }
    - { scenario: milestone-first,  artboard: A9-0 }
```

The scenario names are the JSON files already in `VespersTestKit/Resources/Scenarios/`, so Gate 2 reuses the fixtures Gate 1 runs. Adding a screen to UI review is one line here plus an artboard id from Paper.

`.github/workflows/fleet.yml` in Vespers checks out both repos and calls the gates:

```yaml
on: pull_request
jobs:
  gates:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/checkout@v4
        with: { repository: CZubrecki/fleet, path: ../fleet, ref: main }
      - run: ../fleet/agents/gates/plan-approve.sh --repo . --sha $GITHUB_SHA --check
      - run: ../fleet/agents/gates/behaviour.sh    --repo . --sha $GITHUB_SHA
      - run: ../fleet/agents/gates/ui-review.sh    --repo . --sha $GITHUB_SHA
      - run: ../fleet/agents/gates/review.sh       --repo . --sha $GITHUB_SHA --post
      - uses: actions/upload-artifact@v4
        with: { name: fleet-evidence, path: .fleet/out }
```

The existing `ci.yml` keeps running; `behaviour.sh` wraps the same commands, so for a while the two agree and that agreement is the migration test. Once `fleet.yml` has been green for ten PRs, `ci.yml` goes. Branch protection then requires the four fleet checks, which is what makes Gate 4 a PR Connor can trust rather than one he has to re-verify.

Local use is the same scripts: `../fleet/agents/gates/review.sh --repo . --sha HEAD` from the Vespers folder gives the two-reviewer verdict before a PR exists. The agent building the UI checkpoints can be told to run `behaviour.sh` and `ui-review.sh` itself before declaring a checkpoint done, which is the first place the loop pays for itself.

## Non-goals

- **No Mac mini, no always-on runner.** Gates run on the laptop and on GitHub's macOS runners.
- **No sessions table, no Postgres, no ops-api.** Evidence is JSON files in CI artifacts. The durable ledger is Phase 3; its schema will be whatever these JSON files turn out to need.
- **No remote CLI into the simulator from another machine.** `remote shot` runs where the simulator runs.
- **No eSIM or Totem onboarding.** `.fleet.yaml` is designed so they can be added, but Phase 2 ends with Vespers only. A second app before the gates are stable means debugging two things at once.
- **No FleetCore / FleetUI extraction.** Shared Swift packages come after a second app exists, per the design plan.
- **No auto-merge.** `RISK.yaml` tiers are written but only annotate the PR in Phase 2; Low-tier auto-merge is a Phase 3 decision after the tiers have been watched for a month.
- **No crash-triage or ops-support profiles.** Three profiles, all about shipping code.

## Checkpoint plan

Nine checkpoints, each a PR in `fleet` (and from C5 on, a paired PR in Vespers). Each ends with the self-test green and a one-line entry in `CHANGELOG.md`. Order matters: the cheap deterministic gates come before anything that calls a model, so the harness is proven before the models are.

| # | Checkpoint | Done when |
| --- | --- | --- |
| C1 | Repo skeleton | `fleet` exists with the layout above, `AGENTS.md`, `RISK.yaml`, `fixtures/sample-app/` (one Feature, one passing and one failing vector), `self-test.yml` running an empty gate |
| C2 | `lib/` + `behaviour.sh` | Reads `.fleet.yaml`, runs test + vectors + architecture check, writes `evidence.json`; self-test proves it fails on the planted vector and passes when it is fixed |
| C3 | `plan-approve.sh` | `--approve` writes the hash, `--check` compares; `behaviour.sh` exits 2 when the plan drifted |
| C4 | `models.yaml` + `lib/model.sh` | One function `call_slot <slot> <prompt.md> <inputs...>` returning JSON; cost guard; a `smoke` slot test in self-test with a fixed tiny prompt |
| C5 | `review.sh` + Vespers `.fleet.yaml` | Two reviewers + judge produce findings on a real Vespers PR; `--post` leaves line comments; Vespers `fleet.yml` runs C2, C3, C5 beside `ci.yml` |
| C6 | `fixtures/ui-bench/` + vision slot chosen | 12 pairs built from Paper exports and doctored screenshots; `results.md` committed; `vision_reviewer` set |
| C7 | `ui-review.sh` | Boots simulator, runs the four Vespers scenarios, exports Paper artboards, produces findings; added to Vespers `fleet.yml` |
| C8 | Feedback memory + profiles | `fleet-feedback.yml` in Vespers writes raw entries; `distil.sh` produces its first rules PR; `feature.yaml` and `pr-review.yaml` run end to end on a small Vespers task; `ci.yml` removed after ten green PRs |
| C9 | Ship Vespers through the loop | `release.yaml` wraps the existing Fastlane lanes (bump, build, TestFlight, App Store) and refuses unless the four checks are green on `main`; the rewritten Vespers reaches TestFlight this way, then the App Store; then one small feature (a settings toggle or a new prayer) goes task.md → App Store using only `feature.yaml` + `release.yaml`, timed, and that time is the Phase 2 result |

C1 to C4 need no model calls beyond the smoke test and no Vespers changes; they are a weekend. C5 is the first checkpoint that changes what Connor reads on a PR. C6 is the slowest because the fixtures are hand-made, and it is deliberately before C7 so the UI gate is never trusted before it has been measured.

The Vespers UI work does not wait for any of this. Its checkpoints continue; from C5 on, each new UI PR gets the gates that exist so far, and the findings they raise are the first real feedback memory entries.

## What Phase 3 needs from this

Phase 3 is the ledger and the always-on runner: a `sessions` table in a small `ops-api` (NestJS, Railway, beside the eSIM services), and the eSIM content engine writing its own rows into it. Phase 2 has to leave three things in a state Phase 3 can build on without rework.

1. **`evidence.json` is the ledger row.** Its fields (gate, sha, prompt_sha, model, verdict, findings, started, duration) are the `sessions` schema; Phase 3 adds a `POST /evidence` endpoint and a one-line `curl` at the end of each gate. No gate changes.
2. **Gates take `--repo` and `--sha`, never assume cwd.** That is what lets a runner execute them against a fresh clone in a disposable sandbox instead of Connor's working tree.
3. **Slots, not models, in every prompt and script.** A runner may use a local model for `bulk_reader` and `judge`; `models.yaml` is the only file that changes.

**The Mac mini is deferred, not scheduled.** Phase 3 as written in the design plan assumed a mini; it does not need one. What the mini was for, and what stands in until the substitute hurts:

| Mini job | Substitute | Buy the mini when |
| --- | --- | --- |
| Run gates on every PR | GitHub-hosted `macos-15` runners (free minutes on a public repo; private repo minutes at 10x Linux rate) | Monthly runner bill passes ~$80 CAD for three months running |
| Overnight agent sessions, nightly profile | Laptop left on with a `launchd` job; `distil.sh` and anything without a simulator runs on Railway (Linux) | Nightly work needs the simulator and the laptop is needed elsewhere |
| Ledger, ops-api, sessions table | Railway, beside the eSIM services; never needed a Mac | Never |
| Remote CLI into a simulator from a phone | Hosted Mac by the hour (MacStadium, Scaleway M-series) for a week to see if it is used | Hosted Mac bill for a month exceeds a third of the mini's price |
| Local models for `bulk_reader`/`judge` | Cheap hosted models via `models.yaml` | Only if token spend on those two slots exceeds ~$40 CAD a month |

The honest trigger is the first row. Until Vespers plus a second app are producing enough PRs that runner minutes cost real money, the mini is a $2,599 convenience and the laptop is the runner.

The open question Phase 2 should answer by its end, with data from the evidence files: how often does Gate 3 find something Connor would have caught, and how often does it find something he would not have? That ratio decides whether Phase 3 turns on Low-tier auto-merge or keeps him on every PR for another phase.

**Sources.** Design plan: https://claude.ai/artifact/EysJZZrgt4cieF8JWFrTvR. PRDs this builds on: Router https://claude.ai/artifact/Cdeo8L66SXY3EB3Kp18dFU, Vespers Core https://claude.ai/artifact/PtUKw4PmNTiVDxbUhDAchg, Vespers UI https://claude.ai/artifact/C1Hvr2vEhtwtUZA8MgH9K4. Patterns: Shopify headless core and checkpoint-and-gate, Meta thin orchestrator, Auth0 risk tiers, Spotify shunt, all summarised in the design plan's article tables.
