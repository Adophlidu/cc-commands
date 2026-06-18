#!/usr/bin/env bash
# statusline.sh — d status-line renderer. Wraps any prior status line and appends
# the current d workflow node when a fresh project state file is present.
set -uo pipefail

TTL="${D_STATUS_TTL:-21600}"            # 6h staleness backstop
BASE_CFG="$HOME/.claude/d/base-statusline.json"

input="$(cat)"

# --- base render (wrap prior status line, else default) ----------------------
base=""
if [ -f "$BASE_CFG" ]; then
  base_cmd="$(jq -r '.command // empty' "$BASE_CFG" 2>/dev/null || true)"
  [ -n "$base_cmd" ] && base="$(printf '%s' "$input" | bash -c "$base_cmd" 2>/dev/null || true)"
fi
if [ -z "$base" ]; then
  dir="$(printf '%s' "$input"  | jq -r '.workspace.current_dir // empty')"
  model="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
  used="$(printf '%s' "$input"  | jq -r '.context_window.used_percentage // empty')"
  base="$(basename "${dir:-?}") | ${model:-?}"
  [ -n "$used" ] && base="$base | ctx:$(printf '%.0f' "$used")%"
fi

# --- node suffix -------------------------------------------------------------
cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')"
state="$cwd/.claude/d/status.json"
suffix=""
if [ -n "$cwd" ] && [ -f "$state" ]; then
  updated="$(jq -r '.updated // 0' "$state" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  if [ "$updated" -gt 0 ] && [ $((now - updated)) -lt "$TTL" ]; then
    c="$(jq -r '.command // empty' "$state")"; l="$(jq -r '.label // empty' "$state")"
    s="$(jq -r '.step // empty' "$state")";    t="$(jq -r '.total // empty' "$state")"
    slug="$(jq -r '.slug // empty' "$state")"
    suffix=" | 🔵 d:${c} ▸ ${l} (${s}/${t})"
    [ -n "$slug" ] && suffix="${suffix} · ${slug}"
  fi
fi

printf '%s%s' "$base" "$suffix"
