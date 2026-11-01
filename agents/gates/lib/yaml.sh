# shellcheck shell=bash

# yaml_to_json <file>: prints the YAML file as compact JSON. The only place fleet parses YAML.
yaml_to_json() {
    if ! command -v ruby >/dev/null 2>&1; then
        echo "fleet: ruby is required to read YAML ($1)." >&2
        return 2
    fi
    ruby -ryaml -rjson -e 'puts JSON.generate(YAML.safe_load(File.read(ARGV[0])))' "$1"
}
