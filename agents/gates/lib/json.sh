# shellcheck shell=bash

# json_finding <id> <severity> <where> <evidence> <note>: prints one finding as compact JSON.
json_finding() {
    jq -cn --arg id "$1" --arg severity "$2" --arg where "$3" --arg evidence "$4" --arg note "$5" \
        '{id: $id, severity: $severity, where: $where, evidence: $evidence, note: $note}'
}

# json_result_findings <step> <evidence>: reads command output on stdin and prints a finding for every
# failed result line. A result line is a JSON object with "passed": false, or with a non-empty "failures"
# array; this is the shape the apps' CLIs print, one object per line.
json_result_findings() {
    jq -cR --arg step "$1" --arg evidence "$2" '
        fromjson? | objects
        | if (.failures | type) == "array" then
            (.name // "unnamed") as $report
            | .failures[]
            | {
                id: ("\($step):\($report):\(.vector // .name // "unnamed")" + (if .input == null then "" else "@\(.input)" end)),
                severity: "high",
                where: "\($report)/\(.vector // .name // "unnamed")",
                evidence: $evidence,
                note: (if has("expected") then "input \(.input // "-" | tostring): expected \(.expected | tostring), got \(.actual | tostring)" else tojson end)
              }
          elif .passed == false then
            {
                id: "\($step):\(.name // "unnamed")",
                severity: "high",
                where: (.name // "unnamed" | tostring),
                evidence: $evidence,
                note: (.failure // "failed" | tostring)
            }
          else empty end'
}
