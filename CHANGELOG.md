# Changelog

One line per Phase 2 checkpoint.

- C1 Repo skeleton: `AGENTS.md`, `RISK.yaml`, `ops-cli/fleet` dispatcher, `fixtures/sample-app/` with one passing and one planted failing vector, self-test and shellcheck in CI.
- C2 `lib/` and `behaviour.sh`: the gate contract, SHA-bound `evidence.json`, YAML through `yaml_to_json`, findings from result lines, and the file length rule.
- C3 `plan-approve.sh`: `--approve` commits the plan hash, `--check` compares it, and `behaviour.sh` exits 2 until the plan at its SHA is approved.
