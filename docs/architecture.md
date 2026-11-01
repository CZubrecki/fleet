# Fleet architecture

Fleet is a set of deterministic scripts an app's CI calls on every PR.
Each script is a gate; models, when a gate uses one, only produce JSON the script then judges.

## The gate contract

Every gate is `agents/gates/<gate>.sh --repo <path> --sha <sha> [--out <dir>]`.

| Exit | Meaning |
| --- | --- |
| 0 | Pass |
| 1 | Fail: the gate ran and found a problem |
| 2 | Could not run: bad arguments, missing tools or config, a stale SHA, or an unapproved plan |

A gate never assumes the current directory; it works only on `--repo`.
`--out` defaults to `<repo>/.fleet/out`, and the gate replaces `<out>/<gate>/` on every run, so the same SHA always yields the same evidence.

## Evidence

Each run writes `<out>/<gate>/evidence.json`, the row Phase 3's ledger will store.

```json
{
  "gate": "behaviour",
  "sha": "<full commit sha>",
  "fleet_sha": "<fleet commit the gate ran from>",
  "dirty": false,
  "prompt_sha": null,
  "model": null,
  "verdict": "pass | fail | error",
  "error": null,
  "findings": [{"id": "", "severity": "high | medium | low", "where": "", "evidence": "", "note": ""}],
  "started": "2026-11-01T14:02:11Z",
  "duration_s": 84
}
```

Evidence is trusted only when `sha` equals the commit under review, which catches a stale pass after a force-push.
`dirty` is true when the working tree had uncommitted changes; such evidence is for local use only and CI never produces it.
