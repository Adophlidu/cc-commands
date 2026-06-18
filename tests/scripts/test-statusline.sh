#!/usr/bin/env bash
# Test harness for scripts/statusline.sh
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/../../scripts" && pwd)/statusline.sh"
fail=0
has()    { case "$1" in *"$2"*) echo "ok: $3";; *) echo "FAIL: $3 (got '$1')"; fail=1;; esac; }
hasnot() { case "$1" in *"$2"*) echo "FAIL: $3 (unexpected '$2' in '$1')"; fail=1;; *) echo "ok: $3";; esac; }

H="$(mktemp -d)"; mkdir -p "$H/.claude/d"
P="$(mktemp -d)"; mkdir -p "$P/.claude/d"
IN='{"workspace":{"current_dir":"'"$P"'"},"model":{"display_name":"Opus"},"context_window":{"used_percentage":42.3}}'

# 1. default base, no state -> base only, no node
out="$(printf '%s' "$IN" | HOME="$H" bash "$SCRIPT")"
has    "$out" "$(basename "$P") | Opus" "default base dir+model"
has    "$out" "ctx:42%"                 "default base ctx"
hasnot "$out" "d:"                       "no node when no state"

# 2. fresh state -> node with slug
jq -n --argjson u "$(date +%s)" '{command:"task",label:"implement",step:4,total:6,slug:"0007",updated:$u}' > "$P/.claude/d/status.json"
out="$(printf '%s' "$IN" | HOME="$H" bash "$SCRIPT")"
has "$out" "d:task" "fresh node shown (command)"
has "$out" "implement (4/6)" "fresh node shown (label/step)"
has "$out" "0007" "fresh node shown (slug)"

# 3. stale state -> node hidden
jq -n --argjson u "$(( $(date +%s) - 99999 ))" '{command:"task",label:"old",step:1,total:6,updated:$u}' > "$P/.claude/d/status.json"
out="$(printf '%s' "$IN" | HOME="$H" bash "$SCRIPT")"
hasnot "$out" "d:task" "stale node hidden"
rm -f "$P/.claude/d/status.json"

# 4. wrapped prior base preserved + node appended
jq -n '{type:"command",command:"echo CUSTOMBAR"}' > "$H/.claude/d/base-statusline.json"
jq -n --argjson u "$(date +%s)" '{command:"fix",label:"root-cause",step:2,total:6,updated:$u}' > "$P/.claude/d/status.json"
out="$(printf '%s' "$IN" | HOME="$H" bash "$SCRIPT")"
has "$out" "CUSTOMBAR" "wrapped base preserved"
has "$out" "d:fix" "node appended to wrapped base"

rm -rf "$H" "$P"
[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
