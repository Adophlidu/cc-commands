#!/usr/bin/env bash
# Test harness for scripts/d-status.sh
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/../../scripts" && pwd)/d-status.sh"
fail=0
assert_eq() { # actual expected msg
  if [ "$1" != "$2" ]; then echo "FAIL: $3 (got '$1', want '$2')"; fail=1; else echo "ok: $3"; fi
}

tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude"
state="$tmp/.claude/d/status.json"

# set with slug
( cd "$tmp" && bash "$SCRIPT" set task 4 6 "implement" "0007-add-auth" )
assert_eq "$(jq -r .command  "$state")" "task"          "command written"
assert_eq "$(jq -r .step     "$state")" "4"             "step written"
assert_eq "$(jq -r .total    "$state")" "6"             "total written"
assert_eq "$(jq -r .label    "$state")" "implement"     "label written"
assert_eq "$(jq -r .slug     "$state")" "0007-add-auth" "slug written"
assert_eq "$(jq -r 'has("updated")' "$state")" "true"   "updated stamped"
assert_eq "$(jq -r 'has("pid")'     "$state")" "true"   "pid stamped"

# set without slug omits the key
( cd "$tmp" && bash "$SCRIPT" set init 3 10 "analyze" )
assert_eq "$(jq -r 'has("slug")' "$state")" "false"     "slug omitted when empty"

# clear removes the file, idempotently
( cd "$tmp" && bash "$SCRIPT" clear )
assert_eq "$([ -f "$state" ] && echo present || echo gone)" "gone" "clear removes file"
( cd "$tmp" && bash "$SCRIPT" clear ); assert_eq "$?" "0"          "clear is idempotent"

rm -rf "$tmp"
[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
