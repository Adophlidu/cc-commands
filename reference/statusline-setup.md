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
