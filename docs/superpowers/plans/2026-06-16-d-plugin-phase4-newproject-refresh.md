# d Plugin — Phase 4: New-Project Scaffolding + Incremental Refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete `/d:init` by replacing its two stubs: (1) the **new-project path** — on an empty directory, ask the user to describe the product, infer a `better-t-stack` selection, confirm once, scaffold non-interactively, then fall into the existing-project analysis; and (2) the **incremental-refresh path** — on a re-run of an already-initialized project, re-analyze and update the docs while preserving existing specs and hand-edited agents, consolidating leanly.

**Architecture:** Both paths live in `commands/init.md` (Step 2 = new-project branch; Step 1 = refresh branch), each backed by a reference guide: `reference/better-t-stack.md` (flag taxonomy + requirement→selection mapping + the non-interactive command) and `reference/incremental-refresh.md` (what to refresh, what to preserve, the overwrite-with-ask rule, lean consolidation). The new-project path is a thin front-end that produces a scaffolded codebase and then re-uses the entire existing-project pipeline (Steps 3–14) unchanged. Refresh re-uses the analysis/conventions references but writes in update-not-recreate mode.

**Tech Stack:** Claude Code plugin (markdown command + reference docs), `npx create-better-t-stack` (the scaffolder), the Phase 1–3 manifest + agents + generated commands, `git`. No application runtime — verification is dogfooding `/d:init` on (a) an empty dir and (b) an already-initialized project.

**Adaptation note:** Same as Phases 1–3 — prompt engineering. The new-project dogfood verifies the **constructed scaffold command** (valid `create-better-t-stack` flags) and that control then flows into analysis; it does NOT require a live `npx` run over the network (that is the interactive-acceptance step). The refresh dogfood runs `/d:init` twice on a fixture and asserts the second run updates docs while preserving specs + hand-edits.

**Depends on:** Phases 1–3 (all merged to `main`). This branch is based off `main`.

---

## File Structure

- Create: `reference/better-t-stack.md` — flag taxonomy, requirement→selection mapping, the non-interactive command, post-scaffold handoff.
- Create: `reference/incremental-refresh.md` — refresh-mode rules (re-analyze, update docs, preserve specs + hand-edits, overwrite-with-ask, lean consolidation).
- Modify: `commands/init.md` — replace the Step 1 refresh stub and the Step 2 new-project stub with real behavior that reads those references.
- Modify: `tests/CHECKLIST.md` — add new-project + refresh assertions.
- Create: `tests/CHECKLIST-newproject.md` and `tests/CHECKLIST-refresh.md` — behavior checklists.

---

## Task 1: better-t-stack reference

**Files:**
- Create: `reference/better-t-stack.md`

- [ ] **Step 1: Write the guide**

`reference/better-t-stack.md` must contain:
- **The non-interactive command form**: `npx create-better-t-stack@latest <dir> --yes <flags>` (use `.` for the current directory).
- **Flag taxonomy** (the verified value sets):
  - `--frontend <types...>` (web/native framework, e.g. `tanstack-router`, `react-router`, `next`, `nuxt`, `svelte`, `none`)
  - `--backend <hono|express|fastify|elysia|convex|self|none>`
  - `--database <none|sqlite|postgres|mysql|mongodb>`
  - `--orm <none|drizzle|prisma|mongoose>`
  - `--api <none|trpc|orpc>`
  - `--auth <better-auth|clerk|none>`
  - `--package-manager <npm|pnpm|bun>`
  - `--install` / `--no-install`, `--git` / `--no-git`, plus mention `--runtime`, `--payments`, `--db-setup`, `--examples` exist.
  - **Hard rule:** treat the exact flag values as authoritative only after confirming against `npx create-better-t-stack@latest --help` at runtime, since the tool evolves. State this explicitly.
- **Requirement → selection mapping**: a short heuristic table — e.g. "needs a DB + user accounts" → `--database postgres --orm drizzle --auth better-auth`; "simple static/SPA, no server" → `--backend none --database none`; "API + web app" → `--backend hono --api trpc`. Emphasize the AI infers a sensible default set from the user's described product.
- **Confirmation discipline**: present the full constructed command + a one-line rationale per major choice, get ONE user confirmation, then run it. Allow the user to edit choices before running.
- **Post-scaffold handoff**: after the scaffold succeeds, commit the scaffolded code (`git init` if needed + initial commit) so the existing-project analysis has a clean HEAD baseline, then proceed into the normal analysis pipeline.

- [ ] **Step 2: Verify**

Run: `cd /Users/dudu/cc-commands && grep -E "create-better-t-stack|--frontend|--backend|--database|--help|--yes" reference/better-t-stack.md | wc -l`
Expected: count ≥ 5.

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add reference/better-t-stack.md && git commit -m "docs(d): better-t-stack scaffolding reference"
```

---

## Task 2: incremental-refresh reference

**Files:**
- Create: `reference/incremental-refresh.md`

- [ ] **Step 1: Write the guide**

`reference/incremental-refresh.md` must specify (spec §3.3):
- **Trigger**: `/d:init` finds an existing `.claude/d/manifest.json`.
- **Re-analyze**: re-run architecture analysis and conventions extraction (per `reference/analyze-codebase.md` + `reference/conventions-extraction.md`), scoped where possible by diffing against `manifest.lastAnalyzedCommit`.
- **Update, don't recreate**: edit `docs/architecture/` and `docs/conventions.md` in place — supersede stale entries, keep lean (same discipline as reflow). Do NOT blow away and regenerate.
- **Preserve**:
  - All existing `docs/specs/*` — never touched by refresh.
  - Hand-edited agent files and generated commands: detect divergence from what `/d:init` would generate. For anything that would overwrite a user's hand-edit, **ask before writing** (show the diff, let the user keep/replace/merge). Untouched generated files may be refreshed silently.
- **Stack/role drift**: if the project's stack or detected roles changed (e.g. a backend was added to a former frontend-only project), report the drift and offer to generate the newly-needed agents/commands.
- **Update manifest**: bump `lastAnalyzedCommit` to current HEAD; leave `initializedAt` unchanged; keep `specCounter`.
- **Report**: summarize what was refreshed, what was preserved, and any drift.

- [ ] **Step 2: Verify**

Run: `cd /Users/dudu/cc-commands && grep -E "lastAnalyzedCommit|preserve|specs|hand-edit|ask before|drift" reference/incremental-refresh.md | wc -l`
Expected: count ≥ 4.

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add reference/incremental-refresh.md && git commit -m "docs(d): incremental-refresh reference"
```

---

## Task 3: New-project branch in `/d:init` Step 2

**Files:**
- Modify: `commands/init.md`

- [ ] **Step 1: Read current Step 2**

Current Step 2 (`commands/init.md`) detects new vs existing and, for new, prints `new-project scaffolding (better-t-stack) lands in a later plan.` then STOPs. Read the file for exact wording.

- [ ] **Step 2: Replace the new-project stub with the real flow**

Change Step 2's NEW-project branch (keep the empty/trivial-files detection) to instruct the agent to:
1. Ask the user to describe the product/requirement in natural language (main-agent-driven).
2. READ `${CLAUDE_PLUGIN_ROOT}/reference/better-t-stack.md`. Confirm the current flag set via `npx create-better-t-stack@latest --help`.
3. Infer a `better-t-stack` selection from the requirement and construct the non-interactive command `npx create-better-t-stack@latest . --yes <flags>`.
4. ⏸ Present the command + per-choice rationale and get ONE user confirmation (allow edits). This is a human stop.
5. Run the confirmed command to scaffold into the current directory.
6. Commit the scaffolded code as a clean baseline (`git init` if needed; `git add -A && git commit`).
7. **Fall through into the existing-project pipeline** — run Steps 3–14 against the freshly scaffolded code (do NOT stop).

Keep the EXISTING-project branch ("Otherwise … run Steps 3–14") unchanged. Keep the command-naming comment and all other steps intact.

- [ ] **Step 3: Verify**

Run: `cd /Users/dudu/cc-commands && grep -E "create-better-t-stack|better-t-stack.md|run Steps 3.14|fall through|Steps 3" commands/init.md | wc -l`
Expected: count ≥ 2 (references the better-t-stack guide and the fall-through into Steps 3–14).

Run: `cd /Users/dudu/cc-commands && grep -c "new-project scaffolding (better-t-stack) lands in a later plan" commands/init.md`
Expected: 0 (stub removed).

- [ ] **Step 4: Commit**

```bash
cd /Users/dudu/cc-commands && git add commands/init.md && git commit -m "feat(d): /d:init new-project path (better-t-stack scaffolding)"
```

---

## Task 4: Incremental-refresh branch in `/d:init` Step 1

**Files:**
- Modify: `commands/init.md`

- [ ] **Step 1: Replace the refresh stub**

Change Step 1's "already initialized" branch: instead of printing `... incremental refresh lands in a later plan.` and STOPPING, instruct the agent to READ `${CLAUDE_PLUGIN_ROOT}/reference/incremental-refresh.md` and run the incremental-refresh flow described there (re-analyze, update docs in place, preserve specs + hand-edits with overwrite-with-ask, handle stack/role drift, bump `lastAnalyzedCommit`, report). After refresh, STOP (refresh does not re-run the full generation pipeline — it updates).

Keep the "does not exist → continue to Step 2" branch unchanged.

- [ ] **Step 2: Verify**

Run: `cd /Users/dudu/cc-commands && grep -E "incremental-refresh.md|re-analyze|preserve" commands/init.md | wc -l`
Expected: count ≥ 1 (Step 1 now references the refresh guide).

Run: `cd /Users/dudu/cc-commands && grep -c "incremental refresh lands in a later plan" commands/init.md`
Expected: 0 (stub removed).

Run: `cd /Users/dudu/cc-commands && grep -E "^## .*Step " commands/init.md | grep -oE "Step [0-9]+" | tr '\n' ' '`
Expected: still sequential `Step 1 … Step 14` (no step added/removed — only the two stub bodies changed).

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add commands/init.md && git commit -m "feat(d): /d:init incremental-refresh path"
```

---

## Task 5: Update dogfood checklists

**Files:**
- Modify: `tests/CHECKLIST.md`
- Create: `tests/CHECKLIST-newproject.md`
- Create: `tests/CHECKLIST-refresh.md`

- [ ] **Step 1: Note the scope shift in CHECKLIST.md**

Append to `tests/CHECKLIST.md`:
```markdown
- [ ] (Phase 4) on an EMPTY dir, /d:init runs the new-project path (see CHECKLIST-newproject.md), not the stub
- [ ] (Phase 4) on an ALREADY-INITIALIZED project, /d:init runs incremental refresh (see CHECKLIST-refresh.md), not the stub
```

- [ ] **Step 2: Write the new-project checklist**

Create `tests/CHECKLIST-newproject.md`:
```markdown
# /d:init new-project checklist

Run on an EMPTY directory, with a described requirement (e.g. "a todo web app with accounts and a postgres DB").

- [ ] /d:init asked the user to describe the product (did not stop on the old stub)
- [ ] it read reference/better-t-stack.md and consulted `create-better-t-stack@latest --help`
- [ ] it constructed a non-interactive `npx create-better-t-stack@latest . --yes <flags>` command with valid flags matching the requirement (e.g. --database postgres --auth better-auth)
- [ ] it presented the command + per-choice rationale for ONE confirmation (human stop)
- [ ] after scaffolding (interactive-acceptance: actually run npx in a real session), it committed a baseline and fell through into the existing-project pipeline (Steps 3–14), producing docs, agents, manifest, and the /d:task + /d:fix commands
```

- [ ] **Step 3: Write the refresh checklist**

Create `tests/CHECKLIST-refresh.md`:
```markdown
# /d:init incremental-refresh checklist

Run /d:init once on a fixture (creates manifest + docs + agents). Then hand-edit one agent file and add a docs/specs/0001-foo/ dir. Then run /d:init AGAIN.

- [ ] the second run detected the existing manifest and entered refresh mode (did not stop on the old stub, did not re-scaffold)
- [ ] docs/architecture/ and docs/conventions.md were updated in place (not wiped + recreated)
- [ ] the existing docs/specs/0001-foo/ dir was preserved untouched
- [ ] the hand-edited agent file was NOT silently overwritten — the run asked before replacing it (or left it intact)
- [ ] manifest lastAnalyzedCommit was bumped to current HEAD; initializedAt unchanged; specCounter unchanged
- [ ] the run reported what was refreshed vs preserved
```

- [ ] **Step 4: Verify**

Run: `cd /Users/dudu/cc-commands && ls tests/CHECKLIST-newproject.md tests/CHECKLIST-refresh.md && grep -c "Phase 4" tests/CHECKLIST.md`
Expected: both listed, count ≥ 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/dudu/cc-commands && git add tests/CHECKLIST.md tests/CHECKLIST-newproject.md tests/CHECKLIST-refresh.md && git commit -m "test(d): dogfood checklists for new-project + refresh"
```

---

## Task 6: End-to-end dogfood (new-project command construction + refresh)

**Files:**
- Uses: plugin repo + a scratch empty dir + `tests/fixtures/sample-fullstack`

- [ ] **Step 1: New-project — verify command construction (no live npx)**

In a scratch EMPTY dir `/tmp/d-newproj`, act out `commands/init.md` with requirement "a todo web app with user accounts and a postgres database". Stop at the confirmation step (Step 2.4) WITHOUT running `npx` (the live scaffold is the interactive-acceptance step). Assert:
- the run asked for the requirement and did not print the old stub line,
- it produced a `npx create-better-t-stack@latest . --yes ...` command,
- the flags are valid per `reference/better-t-stack.md` and match the requirement (must include a postgres database flag and an auth flag),
- a per-choice rationale + single confirmation prompt was presented.
Record the constructed command in the report. Walk `tests/CHECKLIST-newproject.md` (the final scaffold+pipeline item is interactive-acceptance — mark it deferred).

- [ ] **Step 2: Refresh — run /d:init twice**

Copy `tests/fixtures/sample-fullstack` to `/tmp/d-refresh`, `git init`, commit. Act out `commands/init.md` once (substitute `${CLAUDE_PLUGIN_ROOT}` → `/Users/dudu/cc-commands`, auto-confirm calibration, AI-decides UI) to fully initialize it (manifest + docs + agents + /d:task + /d:fix). Commit. Then:
- hand-edit `.claude/agents/d-frontend.md` (add a sentinel line `# HAND-EDITED: keep me`),
- create `docs/specs/0001-sample/spec.md` with a line of content,
- commit.
Then act out `commands/init.md` AGAIN on the same dir.

- [ ] **Step 3: Verify refresh behavior**

Assert:
```bash
cd /tmp/d-refresh && \
( grep -q "# HAND-EDITED: keep me" .claude/agents/d-frontend.md && echo "OK: hand-edit preserved" || echo "FAIL: hand-edit lost" ) && \
( test -f docs/specs/0001-sample/spec.md && echo "OK: spec preserved" || echo "FAIL: spec lost" ) && \
python3 -c "import json;m=json.load(open('.claude/d/manifest.json'));print('initializedAt present:', bool(m.get('initializedAt')))"
```
Expected: hand-edit preserved (or the run explicitly asked before replacing it), spec preserved, manifest intact. Walk `tests/CHECKLIST-refresh.md`.

- [ ] **Step 4: Record findings**

Any gap in `reference/better-t-stack.md`, `reference/incremental-refresh.md`, or the two `commands/init.md` branches → record as a FINDING (exact file + problem + fix), fix in plugin source, re-run.

- [ ] **Step 5: Clean up + commit validated state**

```bash
rm -rf /tmp/d-newproj /tmp/d-refresh && cd /Users/dudu/cc-commands && git commit --allow-empty -m "test(d): phase 4 dogfood — new-project command construction + refresh preserve specs/hand-edits"
```

---

## Self-Review (completed)

**Spec coverage (Phase 4 scope = spec §3.1 new project + §3.3 incremental refresh):**
- §3.1 new project — ask requirement, infer better-t-stack selection, one confirmation, non-interactive scaffold, fall into analysis: Task 1 + Task 3 ✓
- §3.3 incremental refresh — re-analyze, update docs in place, preserve specs + hand-edits (overwrite-with-ask), stack/role drift, bump lastAnalyzedCommit: Task 2 + Task 4 ✓
- lean consolidation on refresh (spec §7 discipline applied to refresh): Task 2 ("update, don't recreate", "keep lean") ✓
- **Completes the spec** — after this plan, `/d:init` handles empty dirs, existing projects, and re-runs; `/d:task` and `/d:fix` are generated; reflow keeps docs fresh. No further phases.

**Placeholder scan:** no `{{SLOT}}` introduced (Phase 4 edits the command body and adds references, not generated templates). `${CLAUDE_PLUGIN_ROOT}/reference/...` paths are runtime reads inside the command (correct — `commands/init.md` itself runs with the env var set, unlike the generated project-local commands). No "TBD/handle edge cases" steps.

**Type/name consistency:** manifest fields (`lastAnalyzedCommit`, `initializedAt`, `specCounter`, `roles`, `stack`) match the Phase 1 manifest reference. Step numbering in `commands/init.md` is unchanged (1–14) — Phase 4 only rewrites the Step 1 and Step 2 stub bodies. The new-project path explicitly re-uses Steps 3–14, consistent with the existing-project pipeline. better-t-stack flag values match the design spec §3.1 and are gated behind a runtime `--help` check.

---

## Done after this plan

With Phases 1–4 merged, the full design spec (`docs/superpowers/specs/2026-06-16-d-plugin-design.md`) is implemented: `/d:init` (new / existing / refresh) → generated `/d:task` and `/d:fix` → three-gate verification → knowledge reflow. Remaining work is the **interactive acceptance pass** (install the plugin and exercise `/d:init` on a real empty dir + real existing repo, `/d:task`, `/d:fix` in live sessions) — the one thing the headless dogfoods can't cover.
