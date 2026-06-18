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
