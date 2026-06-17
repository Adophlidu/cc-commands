# d Plugin — Phase 6: Permission Pre-Grant — Implementation Plan

> **For agentic workers:** Small, focused enhancement. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let the user approve **once** at `/d:init` so subsequent file edits/adds — and the project's own gate/git commands — don't prompt on every action during `/d:task` and `/d:fix`. Opt-in; written to `.claude/settings.local.json`.

**Mechanism (confirmed against current Claude Code):**
- `permissions.defaultMode: "acceptEdits"` — auto-accepts Edit/Write/NotebookEdit + basic fs Bash within the project; still prompts for risky Bash (`git push`, network).
- `permissions.allow: ["Bash(<cmd>)", "Bash(<cmd> *)", …]` — whitelists the manifest's gate commands (lint/format/typecheck/test/build) + `git add`/`git commit`.
- Caveats surfaced to the user: `defaultMode` applies on the **next session** (matches the restart `/d:init` already recommends); writing `.claude/settings.local.json` prompts once (the "approve once" moment); `.git`/`.claude` stay protected; no bypass/auto (Claude Code blocks a repo self-granting those).

**Decisions (chosen by the user):** scope = file edits + project gate/git commands; location = `.claude/settings.local.json` (personal, gitignored).

**Depends on:** Phases 1–4 (merged). Independent of Phase 5 (which didn't touch `init.md`).

---

## Changes

- `reference/permissions-setup.md` (new) — the opt-in flow: ask → build block from manifest gate commands → merge into `.claude/settings.local.json` (don't clobber) → ensure it's gitignored → note next-session effect.
- `commands/init.md` — new **Step 14 "OFFER PERMISSION PRE-GRANT (opt-in)"** (reads the reference); SUMMARY renumbered to Step 15 and reports whether a pre-grant was written; cross-refs `Steps 3–15`; the bundled-reference list refreshed to include the Phases 2/4/6 references; the intro "human stops" line generalized.
- `tests/CHECKLIST.md` — Phase 6 assertion.

## Tasks

- [x] Author `reference/permissions-setup.md` (opt-in, acceptEdits + gate/git allow, merge-not-clobber, gitignore, next-session note).
- [x] Insert Step 14 into `commands/init.md`; renumber SUMMARY → 15; fix `Steps 3–15` cross-refs; refresh bundled-reference list; generalize the human-stops line.
- [x] Add the Phase 6 dogfood assertion to `tests/CHECKLIST.md`.

## Verification

- Internal consistency checked: steps sequential 1–15; `permissions-setup.md` referenced; `settings.local.json` named in both files; command-naming comment intact; no stray old step refs.
- **Interactive acceptance:** on a live `/d:init`, accept the pre-grant and confirm `.claude/settings.local.json` gets `defaultMode: "acceptEdits"` + the gate/git allow list (valid JSON), and that a restarted session no longer prompts on edits.

## Self-Review

- **Scope:** opt-in pre-grant only; no `bypassPermissions`/`auto` (blocked by Claude Code anyway); `git push` intentionally excluded so it keeps prompting.
- **Safety:** writes only to `.claude/settings.local.json` (personal, gitignored), merges without clobbering, asks before writing.
- **Consistency:** Step 14 reference path matches the file; SUMMARY reports the permission outcome; manifest gate commands are the source for the allow list (no duplication).
