# AGENTS.md

How an agent working in the fleet repo behaves.
Fleet is the harness and the knowledge for Connor's iOS apps; it holds no app code.
The plan it implements is `docs/prd/phase-2-gate-loop.md`.

## Repo map

| Path | Holds |
| --- | --- |
| `agents/gates/` | One script per gate, plus shared bash in `lib/` |
| `agents/prompts/` | Every prompt a model slot runs, versioned as files |
| `agents/profiles/` | Step lists the `fleet run` runner executes |
| `agents/memory/<app>/` | Rules distilled from Connor's PR comments, one folder per app |
| `docs/knowledge/<app>/` | Links to an app's PRDs, design files and artboard map |
| `ops-cli/fleet` | The entrypoint that dispatches to gates and profiles |
| `fixtures/sample-app/` | A small Swift package every gate is tested against |
| `scripts/self-test.sh` | Runs every gate against a scratch git copy of the sample app |

## Commands

| Task | Command |
| --- | --- |
| Self-test | `scripts/self-test.sh` |
| Lint | `shellcheck ops-cli/fleet $(find . -name '*.sh' -not -path './.git/*')` |
| Run a gate on an app | `ops-cli/fleet gate <name> --repo <path> --sha <sha>` |

CI runs both on every PR (`.github/workflows/self-test.yml`), with the self-test on the macOS system bash 3.2 and system Ruby.

## Rules

- Scripts own every side effect: git, credentials, GitHub, and evidence files. Agents produce JSON and prose; scripts decide.
- Prompts are files in `agents/prompts/`, never strings inside a script.
- Gates never branch on an app's name. An app-specific need becomes a key in that app's `.fleet.yaml`.
- No app code and no Router in this repo.
- Every gate change comes with a self-test case against `fixtures/sample-app/` that fails without the change.
- Bash stays compatible with 3.2: no associative arrays, `mapfile`, `${var,,}`, or `|&`.
- YAML is read only through `yaml_to_json` in `agents/gates/lib/yaml.sh`; everything after that is jq.
- Each checkpoint is one PR with the self-test and lint green and one line in `CHANGELOG.md`.
- When unsure, stop and ask one question naming the smallest decision, with the evidence gathered so far.
