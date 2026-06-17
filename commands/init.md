---
description: Initialize the d workflow for this project (detect, analyze, generate tailored subagents)
argument-hint: [path-to-project] (defaults to current directory)
---
<!-- command-naming: verified /d:init. Evidence: `claude plugin install d@d-dev`
     succeeded and `claude plugin details d` lists the component as "init" under
     plugin "d" (installed at cache/d-dev/d/0.1.0/commands/init.md). Command name =
     filename minus .md (init); namespace = plugin.json name (d) => namespaced
     invocation /d:init. Cross-checked vs reference plugin commit-commands:
     commands/commit.md (no name field) => /commit and namespaced /commit-commands:commit.
     Layout: commands/init.md (flat). Confidence: high. -->

You are running `/d:init` — the keystone initializer for the **d** project-workflow engine.
Your job: analyze the target project, generate tailored subagents, and write the d manifest.
Follow the numbered steps **in order**. Do not skip steps. Some steps are HUMAN STOPS or opt-in prompts
(the Step 8 calibration checkpoint, the Step 2 new-project scaffold confirm, UI setup, the Step 14
permission pre-grant) — honor them; do not proceed past a required stop autonomously.

## Bundled reference files (read these at their step)

This command ships reference docs alongside the plugin. Read each by its **absolute** path using
the plugin-root environment variable `${CLAUDE_PLUGIN_ROOT}` (Claude Code sets this to the plugin's
install directory at runtime). The files are:

- `${CLAUDE_PLUGIN_ROOT}/reference/analyze-codebase.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions-extraction.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/command-extraction.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/detect-roles.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/ui-setup.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/better-t-stack.md` (new-project scaffolding, Step 2)
- `${CLAUDE_PLUGIN_ROOT}/reference/incremental-refresh.md` (re-run, Step 1)
- `${CLAUDE_PLUGIN_ROOT}/reference/permissions-setup.md` (permission pre-grant, Step 14)
- `${CLAUDE_PLUGIN_ROOT}/reference/manifest.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/command-templates/task.template.md` and `fix.template.md` (Steps 10–11)
- `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` (its absolute path is baked into the generated /d:task and /d:fix at Steps 10–11)
- `${CLAUDE_PLUGIN_ROOT}/reference/agent-templates/d-pm.md` and one sibling per detected role
  (`reference/agent-templates/d-pm.md`, `d-tester.md`, `d-reviewer.md`, `d-frontend.md`, `d-backend.md`, `d-ui.md`)

If `${CLAUDE_PLUGIN_ROOT}` is somehow unset, do NOT use a bare relative path (the command runs in the
**target project's** working directory, so `reference/...` would resolve there and miss). Instead locate
the installed `d` plugin directory (search under `~/.claude/plugins/` for a path ending in `/d/<version>/`
that contains `reference/`) and read the files from there; warn the user that the env var was missing.

**TARGET PROJECT** = the directory in `$ARGUMENTS` if provided, else the current working directory.
All project artifacts (`docs/`, `.claude/agents/`, `.claude/d/`) are written **inside the TARGET project**,
never inside the plugin.

---

## Step 1 — DETECT STATE (already initialized?)

Check whether `<target>/.claude/d/manifest.json` exists.

- If it **exists**: the project is already initialized → run the **incremental-refresh flow**.
  READ `${CLAUDE_PLUGIN_ROOT}/reference/incremental-refresh.md` and follow it exactly:
  - **Re-analyze**, scoped by the diff between `manifest.lastAnalyzedCommit` and current HEAD.
  - **Update docs in place** — refresh `<target>/docs/architecture/` and `<target>/docs/conventions.md`,
    editing existing files rather than regenerating from scratch.
  - **Preserve specs and hand-edits** — never touch `<target>/docs/specs/*`, and treat hand-edited
    agent/command files as authoritative. Use **overwrite-with-ask**: before overwriting any hand-edit,
    show the diff and offer **keep / replace / merge**.
  - **Handle stack/role drift** — report any change in detected stack or roles, and offer to generate
    newly-needed agents/commands.
  - **Bump `lastAnalyzedCommit`** to current HEAD; leave `initializedAt` and `specCounter` unchanged.
  - **Report** what was refreshed vs. preserved.
  Then **STOP** — refresh updates in place; it does **not** re-run the first-time generation pipeline
  (do not continue to Step 2).
- If it does **not** exist: continue to Step 2.

## Step 2 — DETECT NEW vs EXISTING

List the target directory's contents. If the directory is empty, or contains **only** trivial files
(`.git`, `README*`, `LICENSE*`, `.gitignore` — in any combination), treat it as a NEW project and run
the **new-project scaffolding flow** below. Otherwise it is an EXISTING project → run Steps 3–15 below.

### NEW project → scaffold, then fall through

When the directory is NEW, scaffold a runnable codebase with **better-t-stack** before running the
analysis pipeline. Do the following in order:

1. **Gather the requirement (main-agent-driven).** Ask the user to describe, in natural language, the
   product they want to build — what it does, who uses it, and any must-have capabilities (accounts,
   database, realtime, mobile, API-only, etc.). Drive this as a normal main-agent conversation; do not
   guess silently.
2. **Load the scaffolding reference and confirm the live flag set.** READ
   `${CLAUDE_PLUGIN_ROOT}/reference/better-t-stack.md` and follow it exactly (flag taxonomy,
   requirement→selection mapping, confirmation discipline, post-scaffold hand-off). Then confirm the
   **current** flag set by running `npx create-better-t-stack@latest --help` — if any flag name or
   accepted value differs from the reference, trust `--help`.
3. **Infer the selection and construct the command.** From the user's requirement, infer a complete
   better-t-stack selection using the reference's mapping table (the user should not have to name
   flags). Construct the non-interactive command by setting **every prompt-bearing flag explicitly** —
   do **NOT** use `--yes` (it is mutually exclusive with the stack flags on current CLI versions).
   Validate the command first with `--dry-run` (exits 0 and prints a canonical `reproducibleCommand`).
   Scaffold into the current directory; use `--no-git` so this command owns the initial commit.
4. **⏸ CONFIRM THE SCAFFOLD (REQUIRED HUMAN STOP).** Present the full constructed command together with
   a **per-choice rationale** (one line explaining each non-default flag). Ask for exactly **one**
   confirmation, and allow the user to edit any choice in free text ("use sqlite", "switch to bun").
   Reconstruct the command from any edits. **STOP and wait for the user — do not run the scaffold until
   they confirm.** Require only one round; do not loop.
5. **Run the scaffold.** Execute the confirmed command exactly as constructed, streaming output. If it
   exits non-zero, report the error and **STOP** — do not proceed to later steps.
6. **Commit a clean baseline.** Create the initial commit so the pipeline has a stable HEAD to compare
   against: `git init` (use `git init -b main` if the directory is not already a repo) if needed, then
   `git add -A && git commit -m "chore: scaffold project with create-better-t-stack"`. Do not push.
7. **Fall through into the existing-project pipeline.** With the scaffold committed, treat the freshly
   scaffolded code as an existing project and **continue into Steps 3–15 below — do NOT stop.**

## Step 3 — ANALYZE ARCHITECTURE

READ `${CLAUDE_PLUGIN_ROOT}/reference/analyze-codebase.md` and follow it exactly.
Produce the architecture docs under `<target>/docs/architecture/` as that reference specifies.

## Step 4 — CONVENTIONS

READ `${CLAUDE_PLUGIN_ROOT}/reference/conventions-extraction.md` and follow it exactly.
Write `<target>/docs/conventions.md`. Where the project is missing lint / format / tsconfig
configuration, AUTHOR the missing config files as that reference instructs.

## Step 5 — EXTRACT & VERIFY COMMANDS

READ `${CLAUDE_PLUGIN_ROOT}/reference/command-extraction.md` and follow it exactly.
Resolve concrete, working command strings for the **qualityGate** (lint/format/typecheck)
and the **testGate** (test/build). You MUST actually RUN each candidate command once to confirm it works;
record the exact command strings that succeed. Do not invent commands you have not run.

## Step 6 — DETECT ROLES

READ `${CLAUDE_PLUGIN_ROOT}/reference/detect-roles.md` and follow it exactly.
Determine the project's `projectType` and the list of `roles[]` (subset of:
d-pm, d-tester, d-reviewer, d-frontend, d-backend, d-ui).

## Step 7 — UI SETUP (conditional)

**ONLY IF** `roles[]` includes `d-ui`: READ `${CLAUDE_PLUGIN_ROOT}/reference/ui-setup.md` and follow it
to establish the `uiBaseline`. **If `d-ui` is not in roles, SKIP this step entirely** and set
`uiBaseline` to null/empty per the manifest reference.

---

## ⏸ Step 8 — CALIBRATION CHECKPOINT (REQUIRED HUMAN STOP)

**STOP and wait for the user.** Do NOT generate agents or write the manifest until the user confirms.

Present a concise summary for the user to review and correct:

1. **Architecture summary** — the key findings from Step 3.
2. **Conventions highlights** — notable rules and any config files you authored in Step 4.
3. **Role roster** — `projectType` and the `roles[]` you detected (Step 6).
4. **Resolved gate commands** — the exact `qualityGate` and `testGate` strings you verified (Step 5).
5. **uiBaseline** — from Step 7 (or "n/a — no d-ui role").
6. **Trunk branch** — ask which branch is the trunk (default `main`; detect the repo's current default if obvious). `/d:task` and `/d:fix` will branch off it and never commit directly to it. Record the answer as `trunkBranch`.

Then ask the user to confirm or correct, using `AskUserQuestion` (or an explicit
"⏸ Reply to confirm, or tell me what to change." prompt). Apply any corrections before continuing.
**This checkpoint is mandatory — never proceed past it autonomously.**

---

## Step 9 — GENERATE AGENTS

For **each** role in the (now user-confirmed) `roles[]`:

- READ the matching template `${CLAUDE_PLUGIN_ROOT}/reference/agent-templates/<role>.md`.
- Fill in **EVERY** `{{SLOT}}` from the extracted data: inline the project's actual convention rules,
  real exemplar file paths, resolved gate commands, stack details, etc.
- WRITE the filled result to `<target>/.claude/agents/<role>.md`.

**Absent-evidence slots:** some slots reference real exemplars that a skeletal project may not have yet
(any `{{*_EXEMPLAR}}` slot — e.g. `{{TEST_EXEMPLAR}}`, `{{DATA_EXEMPLAR}}`, `{{SCHEMA_EXEMPLAR}}`,
`{{HANDLER_EXEMPLAR}}`, `{{COMPONENT_EXEMPLAR}}` — when there are no tests / no data layer / no schema / no handlers / no components yet).
When the evidence genuinely does not exist, fill the slot with the canonical fallback
`(none yet — establish the pattern when first added)` rather than inventing a fake path.

**Hard requirement:** no `{{SLOT}}` placeholder may remain in any generated agent file.
After writing, grep the generated files for `{{` and fix any that remain before continuing.

---

## Step 10 — GENERATE THE `/d:task` COMMAND

Generate the project-local `/d:task` command from the bundled template so the project can iterate
requirements after init.

- READ `${CLAUDE_PLUGIN_ROOT}/reference/command-templates/task.template.md`.
- Fill **EVERY** `{{SLOT}}` from the extracted/confirmed data — at minimum `{{PROJECT_NAME}}` (the
  target project's name), plus any other `{{SLOT}}` the template contains.
- Replace the literal token `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` that appears in the template
  body with the **ABSOLUTE resolved path** to this plugin's own `reference/reflow.md` — i.e. expand
  `${CLAUDE_PLUGIN_ROOT}` to its actual value at generation time (e.g.
  `<plugin-root>/reference/reflow.md`). The generated command lives in the **target project** and must
  NOT depend on `${CLAUDE_PLUGIN_ROOT}` being set in the user's future sessions, so this token must be
  fully expanded, not copied verbatim.
- WRITE the filled result to `<target>/.claude/commands/d/task.md`. The `d/` subdirectory is
  **REQUIRED** so the command is invoked as `/d:task`.

**Hard requirement:** no `{{SLOT}}` placeholder may remain in the output, and no unexpanded
`${CLAUDE_PLUGIN_ROOT}` may remain. After writing, grep `<target>/.claude/commands/d/task.md` for
`{{` and `${CLAUDE_PLUGIN_ROOT}` and fix any that remain before continuing.

---

## Step 11 — GENERATE THE `/d:fix` COMMAND

Generate the project-local `/d:fix` command from the bundled template so the project can diagnose and
fix bugs after init.

- READ `${CLAUDE_PLUGIN_ROOT}/reference/command-templates/fix.template.md`.
- Fill **EVERY** `{{SLOT}}` from the extracted/confirmed data — at minimum `{{PROJECT_NAME}}` (the
  target project's name), plus any other `{{SLOT}}` the template contains.
- Replace the literal token `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` that appears in the template
  body with the **ABSOLUTE resolved path** to this plugin's own `reference/reflow.md` — i.e. expand
  `${CLAUDE_PLUGIN_ROOT}` to its actual value at generation time (e.g.
  `<plugin-root>/reference/reflow.md`). The generated command lives in the **target project** and must
  NOT depend on `${CLAUDE_PLUGIN_ROOT}` being set in the user's future sessions, so this token must be
  fully expanded, not copied verbatim.
- WRITE the filled result to `<target>/.claude/commands/d/fix.md`. The `d/` subdirectory is
  **REQUIRED** so the command is invoked as `/d:fix`.

**Hard requirement:** no `{{SLOT}}` placeholder may remain in the output, and no unexpanded
`${CLAUDE_PLUGIN_ROOT}` may remain. After writing, grep `<target>/.claude/commands/d/fix.md` for
`{{` and `${CLAUDE_PLUGIN_ROOT}` and fix any that remain before continuing.

---

## 🟢 Step 12 — GREEN-BASELINE SELF-TEST (REQUIRED GATE)

Run the resolved **qualityGate** and **testGate** commands (Step 5) against the **current HEAD**.

- If both pass on clean existing code → green baseline established.
- If a gate **fails on clean existing code**, the gate config is wrong, not the code. Fix the gate
  config and **re-run until green**. If no config can possibly make it pass (e.g. project has no
  tests at all), record the gap explicitly instead of forcing a fake pass.

Capture the green-baseline result for the manifest and summary.

---

## Step 13 — WRITE MANIFEST

READ `${CLAUDE_PLUGIN_ROOT}/reference/manifest.md` and follow its schema exactly.
WRITE `<target>/.claude/d/manifest.json`, filling **all** fields:

- `version: 1`
- `projectType`, `stack`, `roles`
- `qualityGate`, `testGate` (the verified command strings from Step 5)
- `uiBaseline` (from Step 7, or null)
- `trunkBranch` (from the Step 8 calibration answer; default `main`)
- `specCounter: 0`
- `initializedAt` (current timestamp)
- `lastAnalyzedCommit` = current HEAD sha (`git rev-parse HEAD` in the target repo)

## Step 14 — OFFER PERMISSION PRE-GRANT (opt-in)

READ `${CLAUDE_PLUGIN_ROOT}/reference/permissions-setup.md` and follow it. **Ask the user first**; only
if they accept, write an `acceptEdits` + gate/git allow block into `<target>/.claude/settings.local.json`
(merging, not clobbering) so future `/d:task` / `/d:fix` runs don't prompt on every edit. If they decline,
skip. Note that it applies after a session restart.

## Step 15 — SUMMARY

Print a clear final summary covering:

- **Docs created** — paths under `docs/architecture/` and `docs/conventions.md`.
- **Agents generated** — each `.claude/agents/<role>.md`.
- **Commands generated** — `.claude/commands/d/task.md` and `.claude/commands/d/fix.md`
  (both `/d:task` and `/d:fix` are now available in this project).
- **Manifest** — `.claude/d/manifest.json` written.
- **Gate commands** — the resolved `qualityGate` and `testGate`.
- **Green-baseline result** — pass, or the recorded gap from Step 12.
- **Permissions** — whether a pre-grant was written to `.claude/settings.local.json` (and that it applies next session), or skipped.
- A note that `/d:task` and `/d:fix` are now generated and available in this project.
