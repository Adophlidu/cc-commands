# Design — Status-line workflow progress (Phase 8)

**Date:** 2026-06-18
**Status:** Approved (design), pending implementation plan
**Topic:** Show the current `d` workflow node in the Claude Code status line during `/d:init`, `/d:task`, `/d:fix`.

---

## 1. Problem & goal

`/d:init`, `/d:task`, and `/d:fix` are multi-node flows, but while one is running the user has no at-a-glance sense of *where* it is — they have to read the transcript. The goal: surface the current flow node in the Claude Code status line, so the bar reads e.g.:

```
cc-commands | Opus | ctx:42% | 🔵 d:task ▸ implement (4/6)
```

**One-line architecture:** the workflow "punches a clock" into a state file as it crosses each node; a wrapped global `statusLine` script reads that file and appends the node to the user's existing status bar.

### Decisions locked in brainstorming

| Decision | Choice |
|---|---|
| Granularity | **Phase-level** nodes (not per-substep; reject-loop rounds not expanded) |
| Integration | **Augment the global status line** by *wrapping* any existing one (Claude Code allows only one `statusLine`) |
| Positioning | **Plugin feature**, wired up by an **opt-in step in `/d:init`** (sibling to the existing permission pre-grant step) |
| Scope | **All three** commands instrumented: `/d:init`, `/d:task`, `/d:fix` |
| Node labels | **English** (repo + README are English; plugin is distributed). Chinese previews in brainstorming were illustrative only. Open to override on review. |

---

## 2. Node maps (what the bar shows)

Labels are short, phase-level. Transient/closing steps (spec checkpoint, reflow) fold into the adjacent node rather than taking their own slot. The reject loop is **not** expanded — the bar stays on the gate node across retries.

**`/d:task`** — 6 nodes
`🌿 branch → 📋 spec → 🧪 acceptance → 🛠 implement → 🚦 gates → 🔀 PR`

**`/d:fix`** — 6 nodes
`🌿 branch → 🔍 root-cause → 🩹 fix → 🧪 regression → 🚦 gates → 🔀 PR`

**`/d:init`** — branch-dependent, up to ~10 nodes
- New-project prefix: `❓ requirement → 🏗 scaffold`
- Existing-project mainline: `🔬 analyze → 📐 conventions → 🚦 run-gates → 🎭 roles → 🎨 ui → ⏸ calibrate → 🤖 agents → ⚙ commands → 🟢 self-test → ✅ ready`

Rendered suffix format: ` | 🔵 d:<command> ▸ <label> (<step>/<total>)`. The `slug` (when present, e.g. a task spec id) is appended in parentheses after the label when it fits: `🔵 d:task ▸ implement (4/6) · 0007-add-auth`.

---

## 3. Components

Three units, each independently testable.

### 3.1 State file — `<project>/.claude/d/status.json`

Single source of truth for "what node is the active flow at". Machine-local and ephemeral — **gitignored**.

```json
{
  "command": "task",          // init | task | fix
  "label": "implement",       // human label of the current node
  "step": 4,
  "total": 6,
  "slug": "0007-add-auth",    // optional — spec/fix slug, omitted for init
  "pid": 12345,               // writer PID, for staleness diagnosis
  "updated": 1718700000       // epoch seconds — TTL backstop
}
```

- **What it does:** holds the current node; absent file = no active flow.
- **How to use it:** written by `d-status.sh`, read by `statusline.sh`.
- **Depends on:** nothing.

### 3.2 Clock-punch script — `scripts/d-status.sh` (shipped in plugin)

```
d-status.sh set <command> <step> <total> <label> [slug]   # write/replace status.json (+ pid, +updated)
d-status.sh clear                                          # remove status.json
```

- Resolves the project root (walks up for `.claude/`, falls back to `$PWD`), writes JSON atomically (temp + mv).
- `set` stamps `pid` and `updated`. Time comes from the shell (`date +%s`) — the script runs in the real shell, not the scripting sandbox, so this is fine.
- `clear` is idempotent (no error if the file is already gone).
- **What it does:** the only writer of the state file.
- **How to use it:** the conductor runs it at each node boundary (`set`) and at terminal nodes (`clear`).
- **Depends on:** the state-file path convention only.

### 3.3 Renderer — `~/.claude/d/statusline.sh` (installed by `/d:init`)

Installed to a **stable path** (`~/.claude/d/`), not the plugin cache dir, so plugin upgrades that move `CLAUDE_PLUGIN_ROOT` don't break the status bar.

Algorithm:
1. Read all of stdin (the session JSON) into a variable.
2. **Base render:** if `~/.claude/d/base-statusline.json` records a wrapped prior command, feed the same stdin to it and capture its stdout as the base string. Otherwise compute a default base: `<basename cwd> | <model display_name> | ctx:<used%>` (matching the user's current format).
3. **Node suffix:** extract `cwd` from stdin JSON; if `$cwd/.claude/d/status.json` exists and its `updated` is within the TTL backstop, append ` | 🔵 d:<command> ▸ <label> (<step>/<total>)[ · <slug>]`.
4. Print `base` + suffix.

- **What it does:** renders base bar + optional node, wrapping any prior status line.
- **How to use it:** referenced by the global `settings.json` `statusLine.command`.
- **Depends on:** `base-statusline.json` (optional), the state-file convention, `jq`.

---

## 4. The wrapping mechanism (avoiding drift)

Claude Code permits exactly one `statusLine`. To add the node **without** duplicating or fighting the user's existing bar:

1. `/d:init` reads the user's current global `statusLine` config.
2. It saves that config verbatim to `~/.claude/d/base-statusline.json`.
3. It rewrites the global `statusLine.command` to invoke `~/.claude/d/statusline.sh`.
4. At render time, `statusline.sh` re-runs the saved prior command on the same stdin and appends the node.

Consequences:
- The user can keep editing their *real* base bar only if they edit the saved base — so the wrapper records the prior command and, on a later `/d:init`, if it detects the global `statusLine` no longer points at our script, it re-wraps the new one. (Detected via manifest + a sentinel comment in the installed command.)
- Lights up **only** in projects that have a live `status.json` — other projects render exactly as before.
- No prior status line → graceful default base.

---

## 5. `/d:init` opt-in step

A new pipeline step, sibling to the existing permission pre-grant (and placed after it):

1. Explain the feature in one line ("show the live `d` workflow node in your status bar").
2. Detect the existing global `statusLine`:
   - present → offer **"wrap it?"**
   - absent → offer **"install the default bar + node?"**
3. On accept: install `statusline.sh` to `~/.claude/d/`, save `base-statusline.json`, rewrite global `settings.json` `statusLine`.
4. **Global + one-time.** If already installed (manifest flag + sentinel present), report and skip — no re-prompt, no double-wrap.
5. Default is **no change** — only acts on explicit opt-in (consistent with the permission-pre-grant step).

Recorded in `.claude/d/manifest.json`:

```json
"statusLine": { "installed": true, "scope": "global", "wrapped": true }
```

Incremental refresh reads this to avoid re-offering or double-wrapping.

---

## 6. Lifecycle, staleness, reliability

- **Clear on terminal nodes:** every flow calls `d-status.sh clear` at its end states (PR opened / pushed / escalation / abort), so the bar returns to base.
- **TTL backstop:** the renderer hides the node if `updated` is older than a TTL (default **6h**) — guards against a crashed run leaving a stale node forever. 6h is generous enough that a genuinely long-running node won't be hidden mid-flight.
- **Reliability tradeoff (accepted):** the conductor (main agent) executes the `set`/`clear` Bash calls at node boundaries — they are explicit, listed steps in the command templates. If the model skips a punch, the worst case is the bar resting on the most-recent node; this is an indicator only and never affects flow correctness. Phase-level granularity minimizes the number of punch points (≤10 per flow).
- **gitignore:** generated/managed projects add `.claude/d/status.json` to `.gitignore` (it is per-run, machine-local).

---

## 7. Files touched

**New**
- `scripts/d-status.sh` — clock-punch (`set`/`clear`)
- `scripts/statusline.sh` — renderer + wrapper
- `reference/statusline-setup.md` — spec for the `/d:init` opt-in step (mirrors `reference/permissions-setup.md`)
- `tests/CHECKLIST-statusline.md` — manual verification checklist

**Modified**
- `commands/init.md` — add the opt-in step; instrument `/d:init`'s own nodes; add `status.json` to gitignore guidance
- `reference/command-templates/*` — instrument `/d:task` & `/d:fix` node boundaries (`set`) + terminal `clear`
- `reference/manifest.md` — document the `statusLine` field
- `reference/incremental-refresh.md` — don't re-offer / double-wrap when already installed
- `README.md` — feature section + Phase 8 status row

---

## 8. Testing (manual checklist)

1. **set/clear round-trip** — `set` writes well-formed JSON with `updated`/`pid`; `clear` removes it idempotently.
2. **wrap preserves base** — with a prior status line, the bar shows the original content unchanged plus the node.
3. **default base** — with no prior status line, the bar renders `dir | model | ctx%` + node.
4. **idle returns to base** — after `clear`, the node disappears.
5. **TTL backstop** — a `status.json` older than the TTL hides the node.
6. **only-in-d-projects** — in a project without `status.json`, the bar is unchanged.
7. **one-time install** — a second `/d:init` opt-in detects the install and skips without double-wrapping.

---

## 9. Out of scope (YAGNI)

- Per-substep / reject-loop-round granularity (phase-level only).
- Project-local `statusLine` override path (global-wrap chosen).
- A TUI/animated progress bar — this is a single status-line string.
- Auto-tracking node progress via hooks — the conductor punches explicitly.
