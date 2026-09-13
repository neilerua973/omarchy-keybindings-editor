#!/bin/bash
# test/keybindings-data.smoke.sh — run from the plugin root:
#   bash test/keybindings-data.smoke.sh
set -eo pipefail

script="$(dirname "$0")/../bin/keybindings-data"

if [[ ! -x $script ]]; then
  echo "FAIL: $script is missing or not executable"
  exit 1
fi

output=$("$script")

if ! jq empty <<<"$output" 2>/dev/null; then
  echo "FAIL: output is not valid JSON"
  exit 1
fi

count=$(jq 'length' <<<"$output")
if (( count < 1 )); then
  echo "FAIL: expected at least one binding, got $count"
  exit 1
fi

bad=$(jq '[.[] | select((.key | length) == 0 or (.mods | type) != "array")] | length' <<<"$output")
if (( bad > 0 )); then
  echo "FAIL: $bad entries have an empty key or non-array mods"
  exit 1
fi

lower=$(jq '[.[] | select(.key != (.key | ascii_upcase))] | length' <<<"$output")
if (( lower > 0 )); then
  echo "FAIL: $lower entries have a non-upper-case key"
  exit 1
fi

raw_binds=$(hyprctl binds | grep -c '^bind')
if (( count < raw_binds - 5 )); then
  echo "FAIL: JSON has $count bindings, raw hyprctl binds has $raw_binds — too many were dropped"
  exit 1
fi

echo "PASS: $count bindings, valid JSON, keys normalized"
