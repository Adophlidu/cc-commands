#!/usr/bin/env bash
# d-status.sh — workflow clock-punch for the d status line.
#   d-status.sh set <command> <step> <total> <label> [slug]
#   d-status.sh clear
set -euo pipefail

find_project_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    [ -d "$dir/.claude" ] && { printf '%s' "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  printf '%s' "$PWD"
}

ROOT="$(find_project_root)"
STATE_DIR="$ROOT/.claude/d"
STATE_FILE="$STATE_DIR/status.json"

case "${1:-}" in
  set)
    command="${2:?command required}"; step="${3:?step required}"
    total="${4:?total required}";    label="${5:?label required}"
    slug="${6:-}"
    mkdir -p "$STATE_DIR"
    tmp="$(mktemp "$STATE_DIR/.status.XXXXXX")"
    jq -n \
      --arg command "$command" --arg label "$label" \
      --argjson step "$step" --argjson total "$total" \
      --arg slug "$slug" --argjson pid "$$" --argjson updated "$(date +%s)" \
      '{command:$command,label:$label,step:$step,total:$total,pid:$pid,updated:$updated}
       + (if $slug == "" then {} else {slug:$slug} end)' > "$tmp"
    mv -f "$tmp" "$STATE_FILE"
    ;;
  clear)
    rm -f "$STATE_FILE"
    ;;
  *)
    echo "usage: d-status.sh set <command> <step> <total> <label> [slug] | clear" >&2
    exit 2
    ;;
esac
