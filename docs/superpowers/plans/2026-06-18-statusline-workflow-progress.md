# Status-line Workflow Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the current `d` workflow node in the Claude Code status line during `/d:init`, `/d:task`, and `/d:fix`.

**Architecture:** Each flow "punches a clock" into an ephemeral per-project state file (`.claude/d/status.json`) as it crosses a phase-level node. A renderer script — installed to a stable path and *wrapping* any pre-existing status line — reads that file and appends the node to the user's existing bar. Setup is an opt-in step in `/d:init`; it lights up only in projects that have a live state file.

**Tech Stack:** Bash + `jq` (already a hard dependency of the user's existing status line). No build system; the plugin is markdown + shell. Automated tests are bash assertion harnesses under `tests/scripts/`; markdown changes are verified by `grep` + the manual `tests/CHECKLIST-statusline.md`.

## Global Constraints

- **Node labels are English** (repo + README are English; the plugin is distributed).
- **Phase-level granularity only** — the reject loop does **not** advance the node.
- **`jq` is assumed present** (the user's current status line already requires it).
- **One status line** — Claude Code allows a single `statusLine`; integration is by wrapping, never clobbering.
- **Opt-in, global, one-time** — never change settings without an explicit yes; never double-wrap.
- **Generated project commands must NOT depend on `${CLAUDE_PLUGIN_ROOT}`** at the user's runtime — they reference the stable `$HOME/.claude/d/d-status.sh` path instead (this stays literal; `/d:init`'s generation grep only rejects `{{` and `${CLAUDE_PLUGIN_ROOT}`).
- **Punches are best-effort** — every punch is guarded `[ -x <script> ] && <script> ... || true`, so it is a silent no-op when the feature is not installed.
- **Anti-recursion** — never save the wrapper as its own base (would fork-bomb the status line).

---

### Task 1: `d-status.sh` — the clock-punch script

**Files:**
- Create: `scripts/d-status.sh`
- Test: `tests/scripts/test-d-status.sh`

**Interfaces:**
- Produces (CLI contract relied on by Tasks 4 & 5):
  - `d-status.sh set <command> <step> <total> <label> [slug]` — writes/replaces `<project-root>/.claude/d/status.json` with `{command,label,step,total,pid,updated[,slug]}`. `<command>` ∈ `init|task|fix`. `step`/`total` are integers.
  - `d-status.sh clear` — removes the state file; idempotent (exit 0 if already gone).
  - Project root = nearest ancestor of `$PWD` containing `.claude/`, else `$PWD`.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-d-status.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/scripts/test-d-status.sh`
Expected: FAIL — `scripts/d-status.sh` does not exist yet (`bash: .../d-status.sh: No such file or directory`).

- [ ] **Step 3: Write the script**

Create `scripts/d-status.sh`:

```bash
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
```

- [ ] **Step 4: Make it executable and run the test**

Run: `chmod +x scripts/d-status.sh && bash tests/scripts/test-d-status.sh`
Expected: every line `ok:` and a final `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add scripts/d-status.sh tests/scripts/test-d-status.sh
git commit -m "feat(d): d-status.sh — workflow clock-punch state writer"
```

---

### Task 2: `statusline.sh` — renderer + wrapper

**Files:**
- Create: `scripts/statusline.sh`
- Test: `tests/scripts/test-statusline.sh`

**Interfaces:**
- Consumes: session JSON on stdin (fields used: `.workspace.current_dir`, `.model.display_name`, `.context_window.used_percentage`); the state file written by Task 1; optional `$HOME/.claude/d/base-statusline.json` (a saved prior `statusLine` object with a `.command` string).
- Produces: a single status-line string on stdout: `<base>[ | 🔵 d:<command> ▸ <label> (<step>/<total>)[ · <slug>]]`. Node shown only when the state file's `updated` is within `D_STATUS_TTL` (default 21600s = 6h).

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-statusline.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/scripts/test-statusline.sh`
Expected: FAIL — `scripts/statusline.sh` does not exist yet.

- [ ] **Step 3: Write the script**

Create `scripts/statusline.sh`:

```bash
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
```

- [ ] **Step 4: Make it executable and run the test**

Run: `chmod +x scripts/statusline.sh && bash tests/scripts/test-statusline.sh`
Expected: every line `ok:` and a final `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add scripts/statusline.sh tests/scripts/test-statusline.sh
git commit -m "feat(d): statusline.sh — wrapping renderer that appends the workflow node"
```

---

### Task 3: `reference/statusline-setup.md` — the opt-in setup spec

**Files:**
- Create: `reference/statusline-setup.md`

**Interfaces:**
- Consumes: `scripts/d-status.sh`, `scripts/statusline.sh` (Tasks 1–2), `${CLAUDE_PLUGIN_ROOT}` (available inside `/d:init`).
- Produces: the procedure `/d:init` Step 14.5 follows (Task 4 links to this file). Defines the install paths (`~/.claude/d/`), the wrap+anti-recursion rules, the manifest `statusLine` shape, and the gitignore entry.

- [ ] **Step 1: Write the reference doc**

Create `reference/statusline-setup.md`:

````markdown
# Status-line Setup (opt-in)

**Purpose:** Show the current `d` workflow node in the Claude Code status line during
`/d:init`, `/d:task`, `/d:fix` — e.g. `myproject | Opus | ctx:42% | 🔵 d:task ▸ implement (4/6)`.

This is **opt-in** and **global** (Claude Code allows only one status line). Always ask before
changing anything.

---

## How it works

- A per-project state file `<project>/.claude/d/status.json` records the active node (written by
  `d-status.sh set`, removed by `clear`). It is ephemeral and gitignored.
- A renderer `~/.claude/d/statusline.sh` **wraps** any existing status line: it re-runs the user's
  prior status-line command on the same stdin, then appends the node when a fresh state file exists
  for the current project.
- It lights up only in projects that have a live state file; every other project renders exactly as
  before.

---

## Step 1 — Ask (opt-in)

> "Want the status bar to show the live `d` workflow node (e.g. `d:task ▸ implement (4/6)`)? It's a
> one-time global setup that *wraps* your current status line — your existing bar is preserved, and
> other projects are unaffected. [yes / no]"

If **no**, skip this entire step and set `manifest.statusLine = { "installed": false }`.

## Step 2 — Install the scripts to a stable path

Copy both scripts to `~/.claude/d/` so plugin upgrades that move the cache path don't break the bar:

```bash
mkdir -p ~/.claude/d
cp "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh"   ~/.claude/d/d-status.sh
cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh" ~/.claude/d/statusline.sh
chmod +x ~/.claude/d/d-status.sh ~/.claude/d/statusline.sh
```

## Step 3 — Preserve any existing status line (wrap, don't clobber)

Read the current global `statusLine` from `~/.claude/settings.json`.

- **Anti-recursion guard (critical):** if the current `.statusLine.command` already references
  `statusline.sh` (our sentinel), the wrapper is already installed — do **NOT** overwrite
  `~/.claude/d/base-statusline.json` (saving the wrapper as its own base fork-bombs the status line).
  Skip this step's save.
- Else if a `statusLine` exists, save it verbatim so the wrapper can re-run it:
  ```bash
  jq '.statusLine' ~/.claude/settings.json > ~/.claude/d/base-statusline.json
  ```
- Else (no existing status line) do not create `base-statusline.json` — the renderer falls back to a
  default `dir | model | ctx%` bar.

## Step 4 — Point the global status line at the wrapper

Set `~/.claude/settings.json` `statusLine` to:

```json
{ "type": "command", "command": "bash ~/.claude/d/statusline.sh" }
```

**Merge** into the existing settings.json (preserve every other key); validate the result is valid
JSON before writing. The `d/statusline.sh` path doubles as the sentinel that incremental-refresh uses
to detect the install.

## Step 5 — Record in the manifest

Update `<project>/.claude/d/manifest.json`:

```json
"statusLine": { "installed": true, "scope": "global", "wrapped": <true if Step 3 saved a prior bar, else false> }
```

## Step 6 — Keep the state file out of git

Ensure `<project>/.gitignore` ignores the ephemeral state file; if the entry is absent, append:

```
.claude/d/status.json
```

## Step 7 — Tell the user

Note that the status line reloads live (no restart needed) and that nothing else changed; the bar
will show a node the next time a `d` command runs. To undo: delete the `statusLine` key (or restore
it from `~/.claude/d/base-statusline.json`) in `~/.claude/settings.json`.
````

- [ ] **Step 2: Verify structure**

Run: `grep -c '^## Step' reference/statusline-setup.md`
Expected: `7`.
Run: `grep -q 'Anti-recursion guard' reference/statusline-setup.md && echo ok`
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add reference/statusline-setup.md
git commit -m "docs(d): statusline-setup reference — opt-in wrap + install procedure"
```

---

### Task 4: Wire the opt-in step + init progress into `commands/init.md`

**Files:**
- Modify: `commands/init.md`

**Interfaces:**
- Consumes: `reference/statusline-setup.md` (Task 3), `scripts/d-status.sh` (Task 1).
- Produces: a new Step 14.5 (status-line opt-in), an init progress-punch directive, a `statusLine` default in the manifest write (Step 13), and a clear at the end (Step 15).

- [ ] **Step 1: Add the reference file to the bundled list**

In `commands/init.md`, after the `permissions-setup.md` bundled-list line (the line ending `(permission pre-grant, Step 14)`), add:

```
- `${CLAUDE_PLUGIN_ROOT}/reference/statusline-setup.md` (status-line setup, Step 14.5)
```

- [ ] **Step 2: Mention the new opt-in stop in the intro**

In the intro paragraph, change the parenthetical listing the opt-in steps from:

```
(the Step 8 calibration checkpoint, the Step 2 new-project scaffold confirm, UI setup, the Step 14
permission pre-grant) — honor them; do not proceed past a required stop autonomously.
```

to:

```
(the Step 8 calibration checkpoint, the Step 2 new-project scaffold confirm, UI setup, the Step 14
permission pre-grant, the Step 14.5 status-line setup) — honor them; do not proceed past a required
stop autonomously.
```

- [ ] **Step 3: Add the init progress-punch directive**

Immediately after the `---` that ends the "Bundled reference files" section (just before `## Step 1 — DETECT STATE`), insert:

```markdown
## Progress display (status line) — punch at each step

If the status-line feature is installed, surface progress in the bar. Before each major step below,
run this best-effort punch (a silent no-op when the script is absent):

```bash
[ -x "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" ] && "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" set init <step> <total> "<label>" || true
```

Node map (existing-project pipeline, `<total>` = 8):
`1/8 analyze · 2/8 conventions · 3/8 run-gates · 4/8 roles · 5/8 ui · 6/8 calibrate · 7/8 generate · 8/8 self-test`

For a NEW project, prepend two nodes and use `<total>` = 10:
`1/10 requirement · 2/10 scaffold`, then the eight above as `3/10 … 10/10`.

At the very end (after the Step 15 summary), clear the indicator:

```bash
[ -x "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" ] && "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" clear || true
```

Note: on a project's **first-ever** `/d:init`, the wrapper is not installed until Step 14.5, so the
first run shows nothing in the bar; every subsequent `d` command (and future inits) displays normally.

---
```

- [ ] **Step 4: Default the manifest `statusLine` field in Step 13**

In Step 13's bullet list of manifest fields, after the `lastAnalyzedCommit` bullet, add:

```
- `statusLine: { "installed": false }` (Step 14.5 updates this if the user opts in)
```

- [ ] **Step 5: Add Step 14.5 (the opt-in)**

Immediately after Step 14 (the permission pre-grant block, ending `...Note that it applies after a session restart.`) and before `## Step 15 — SUMMARY`, insert:

```markdown
## Step 14.5 — OFFER STATUS-LINE SETUP (opt-in)

READ `${CLAUDE_PLUGIN_ROOT}/reference/statusline-setup.md` and follow it. **Ask the user first**; only
if they accept, install the renderer to `~/.claude/d/`, preserve any existing status line by wrapping
it, point the global `statusLine` at the wrapper, and set `manifest.statusLine.installed = true`. If
they decline, set `manifest.statusLine = { "installed": false }` and skip. This shows the live `d`
workflow node in the status bar during `/d:task` and `/d:fix`.
```

- [ ] **Step 6: Add the clear + status-line line to the Step 15 summary**

In Step 15's summary bullet list, after the `Permissions` bullet, add:

```
- **Status line** — whether the progress display was installed (and that other projects are unaffected), or skipped.
```

And add a final paragraph after the summary bullets:

```
After printing the summary, clear the status-line indicator (best-effort):

```bash
[ -x "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" ] && "${CLAUDE_PLUGIN_ROOT}/scripts/d-status.sh" clear || true
```
```

- [ ] **Step 7: Verify**

Run:
```bash
grep -q 'Step 14.5' commands/init.md && \
grep -q 'Progress display (status line)' commands/init.md && \
grep -c 'd-status.sh' commands/init.md
```
Expected: prints `3` (two punch directives + one clear in Step 15; the Step 3 directive contains both a `set` and a `clear`, so the literal `d-status.sh` occurs 3+ times — confirm the count is ≥ 3) and the two greps succeed.
Run: `grep -q 'statusline-setup.md' commands/init.md && echo ok` → `ok`.

- [ ] **Step 8: Commit**

```bash
git add commands/init.md
git commit -m "feat(d): /d:init offers opt-in status-line setup + punches its own progress"
```

---

### Task 5: Instrument `/d:task` and `/d:fix` templates

**Files:**
- Modify: `reference/command-templates/task.template.md`
- Modify: `reference/command-templates/fix.template.md`

**Interfaces:**
- Consumes: `$HOME/.claude/d/d-status.sh` (installed by Task 3's procedure; literal `$HOME` path, never expanded at generation).
- Produces: progress punches in the generated `/d:task` and `/d:fix` commands.

- [ ] **Step 1: Add the progress directive to `task.template.md`**

In `reference/command-templates/task.template.md`, immediately after the conventions paragraph (the line ending `**Never commit on `trunkBranch`** — all work lands via a PR.`) and before `## Step 0`, insert:

```markdown
## Progress display (status line)

This project may have the d status line installed. At the start of each step below, surface progress
(best-effort; a silent no-op if not installed):

```bash
[ -x "$HOME/.claude/d/d-status.sh" ] && "$HOME/.claude/d/d-status.sh" set task <step> 6 "<label>" "NNNN-<slug>" || true
```

Node map: `1/6 branch · 2/6 spec · 3/6 acceptance · 4/6 implement · 5/6 gates · 6/6 PR`. Use the
`NNNN-<slug>` chosen in Step 0. The reject loop does **not** advance the node — stay on `5/6 gates`
across retries. After the PR is opened (Step 10), clear it:

```bash
[ -x "$HOME/.claude/d/d-status.sh" ] && "$HOME/.claude/d/d-status.sh" clear || true
```
```

- [ ] **Step 2: Add the progress directive to `fix.template.md`**

In `reference/command-templates/fix.template.md`, immediately after the conventions paragraph (the line ending `**Never commit on `trunkBranch`** — all work lands via a PR.`) and before `## Step 0`, insert:

```markdown
## Progress display (status line)

This project may have the d status line installed. At the start of each step below, surface progress
(best-effort; a silent no-op if not installed):

```bash
[ -x "$HOME/.claude/d/d-status.sh" ] && "$HOME/.claude/d/d-status.sh" set fix <step> 6 "<label>" "<slug>" || true
```

Node map: `1/6 branch · 2/6 root-cause · 3/6 fix · 4/6 regression · 5/6 gates · 6/6 PR`. Use the
`<slug>` chosen in Step 0. The reject loop does **not** advance the node — stay on `5/6 gates` across
retries. After the PR is opened (Step 8), clear it:

```bash
[ -x "$HOME/.claude/d/d-status.sh" ] && "$HOME/.claude/d/d-status.sh" clear || true
```
```

- [ ] **Step 3: Verify both templates and confirm no generation-token clash**

Run:
```bash
grep -c 'd-status.sh' reference/command-templates/task.template.md
grep -c 'd-status.sh' reference/command-templates/fix.template.md
grep -c '\${CLAUDE_PLUGIN_ROOT}' reference/command-templates/task.template.md
```
Expected: first two each print `2` (one `set`, one `clear`). The third confirms the punch lines did **not** introduce a `${CLAUDE_PLUGIN_ROOT}` token (count should be unchanged from before — the existing `reflow.md` reference; the new `$HOME` punches add none).

- [ ] **Step 4: Commit**

```bash
git add reference/command-templates/task.template.md reference/command-templates/fix.template.md
git commit -m "feat(d): /d:task & /d:fix punch phase-level progress to the status line"
```

---

### Task 6: Docs — manifest, refresh, README, checklist

**Files:**
- Modify: `reference/manifest.md`
- Modify: `reference/incremental-refresh.md`
- Modify: `README.md`
- Create: `tests/CHECKLIST-statusline.md`

**Interfaces:**
- Consumes: the `statusLine` manifest field (Tasks 4 & 3), the sentinel convention (Task 3 Step 4).
- Produces: schema documentation, refresh handling, user-facing README copy, and the manual verification checklist.

- [ ] **Step 1: Document the manifest field**

In `reference/manifest.md`, in the JSON shape, change the `"specCounter": 0` line to:

```jsonc
  "specCounter": 0,
  "statusLine": { "installed": false, "scope": "global", "wrapped": false }
```

And add this row to the bottom of the field-semantics table:

```
| `statusLine` | object | Whether the opt-in status-line progress display was installed (`/d:init` Step 14.5). `installed` becomes true once the global wrapper is set up; `scope` is `global`; `wrapped` is true if a prior status line was preserved by wrapping. Absent/`{installed:false}` means no status-line integration. |
```

- [ ] **Step 2: Add refresh handling**

In `reference/incremental-refresh.md`, after Step 6 (the drift section, ending before `## Step 7 — Update Manifest`), insert:

```markdown
---

## Step 6.5 — Status line (if installed)

Read `manifest.statusLine`. 

- If `installed` is true: do **not** re-offer setup. Verify the global `~/.claude/settings.json`
  `statusLine.command` still references `statusline.sh` (the sentinel). If the user has since replaced
  it with a different status line, offer to **re-wrap** the new one — but apply the same
  **anti-recursion guard**: never save a command that already references `statusline.sh` as the base
  (see `reference/statusline-setup.md` Step 3). On accept, save the new prior command to
  `~/.claude/d/base-statusline.json` and restore `statusLine.command` to `bash ~/.claude/d/statusline.sh`.
- If `installed` is false: you may offer setup **once** (read `${CLAUDE_PLUGIN_ROOT}/reference/statusline-setup.md`).

This is a small opt-in touch-up; it does not count as re-running first-time generation.
```

- [ ] **Step 3: Update the README**

In `README.md`, add a row to the "Project status" table after the Phase 7 row:

```
| 8 | Status-line workflow progress (opt-in) | ✅ |
```

And add this subsection just before `## Git workflow & conventions`:

```markdown
## Live progress in the status line (opt-in)

Every `d` flow is a sequence of phase-level nodes; with the optional status-line integration, the
current node shows in your Claude Code status bar:

```
myproject | Opus | ctx:42% | 🔵 d:task ▸ implement (4/6)
```

`/d:init` offers this as a one-time, opt-in step. It **wraps** any status line you already have
(your existing bar is preserved), installs a renderer to `~/.claude/d/`, and lights up only in
`d`-managed projects — every other project renders exactly as before. Each flow writes its current
node to an ephemeral, gitignored `.claude/d/status.json` and clears it when the PR opens; a 6-hour
staleness backstop hides a node left behind by an interrupted run.
```

- [ ] **Step 4: Create the manual checklist**

Create `tests/CHECKLIST-statusline.md`:

```markdown
# CHECKLIST — Status-line workflow progress

Manual verification for the opt-in status-line integration.

## Unit (automated)
- [ ] `bash tests/scripts/test-d-status.sh` → `ALL PASS`
- [ ] `bash tests/scripts/test-statusline.sh` → `ALL PASS`

## Setup (in a real d-managed project)
- [ ] `/d:init` Step 14.5 asks before changing anything; declining leaves `~/.claude/settings.json` untouched and `manifest.statusLine.installed = false`.
- [ ] Accepting installs `~/.claude/d/d-status.sh` + `~/.claude/d/statusline.sh` (both executable).
- [ ] An existing status line is saved to `~/.claude/d/base-statusline.json` and still renders (wrapped).
- [ ] With no prior status line, the bar shows the default `dir | model | ctx%`.
- [ ] Re-running `/d:init` opt-in does **not** double-wrap (base-statusline.json is not overwritten with the wrapper).

## Live behavior
- [ ] During `/d:task`, the bar advances through `branch → spec → acceptance → implement → gates → PR`.
- [ ] A failing gate / reject loop keeps the bar on `5/6 gates` (does not advance).
- [ ] During `/d:fix`, the bar advances through `branch → root-cause → fix → regression → gates → PR`.
- [ ] When the PR opens (or the run aborts), the node clears and the bar returns to base.
- [ ] In a project **without** `.claude/d/status.json`, the bar is unchanged (no node).
- [ ] A `status.json` older than 6h hides the node (TTL backstop).
- [ ] `.claude/d/status.json` is gitignored in the managed project.
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -q 'statusLine' reference/manifest.md && \
grep -q 'Step 6.5' reference/incremental-refresh.md && \
grep -q 'Live progress in the status line' README.md && \
grep -q 'Status-line workflow progress' README.md && \
test -f tests/CHECKLIST-statusline.md && echo "all docs ok"
```
Expected: `all docs ok`.

- [ ] **Step 6: Run the full automated suite once more**

Run: `bash tests/scripts/test-d-status.sh && bash tests/scripts/test-statusline.sh`
Expected: two `ALL PASS` lines.

- [ ] **Step 7: Commit**

```bash
git add reference/manifest.md reference/incremental-refresh.md README.md tests/CHECKLIST-statusline.md
git commit -m "docs(d): document status-line field, refresh handling, README + checklist (phase 8)"
```

---

## Self-Review

**Spec coverage:**
- §2 node maps → Tasks 4 (init), 5 (task/fix). ✅
- §3.1 state file → Task 1 (writer), Task 2 (reader), Task 3 §6 (gitignore). ✅
- §3.2 clock-punch script → Task 1. ✅
- §3.3 renderer (stable path, wrap, default base) → Task 2 + Task 3 §2/§4. ✅
- §4 wrapping + anti-drift → Task 3 §3/§4 (incl. anti-recursion guard, sentinel). ✅
- §5 `/d:init` opt-in step + manifest field → Task 4 (Step 14.5, manifest default), Task 3 §5. ✅
- §6 lifecycle/staleness/reliability → Task 2 (TTL), Tasks 4/5 (clear at terminal + guarded punches), Task 3 §7. ✅
- §7 files touched → all six tasks cover the listed files. ✅
- §8 testing → Tasks 1/2 automated, Task 6 `CHECKLIST-statusline.md`. ✅
- §9 out-of-scope → honored (no per-substep granularity, no project-local override, no hooks). ✅

**Placeholder scan:** No TBD/TODO. The `<step>`/`<label>`/`<total>`/`NNNN-<slug>` tokens in Tasks 4–5 are *intended literal instructions* for the conductor (it substitutes them at runtime per the node map), not plan placeholders — each is accompanied by an explicit map.

**Type/name consistency:** `d-status.sh set <command> <step> <total> <label> [slug]` and `clear` are used identically in Tasks 1, 4, 5. State-file fields (`command,label,step,total,pid,updated,slug`) match between the writer (Task 1) and reader (Task 2). Install paths (`~/.claude/d/d-status.sh`, `~/.claude/d/statusline.sh`, `~/.claude/d/base-statusline.json`) are consistent across Tasks 2, 3, 4, 5, 6. Sentinel (`statusline.sh` in the command) consistent between Task 3 §4 and Task 6 Step 2.
