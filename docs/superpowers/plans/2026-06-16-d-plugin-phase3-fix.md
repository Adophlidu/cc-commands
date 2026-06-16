# d Plugin — Phase 3: `/d:fix` Bug-Fix Workflow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/d:init` generate a project-local `/d:fix` command, and author the `/d:fix` orchestration: `d-tester` finds the root cause → human diagnosis checkpoint → fix routed to the owning worker → verify with a regression test + quality gate (reject loop, 3-round escalation) → knowledge reflow → lightweight record + report.

**Architecture:** `/d:fix` is a *generated, project-local* command at `<target>/.claude/commands/d/fix.md` (the `d/` subdirectory yields `/d:fix`), authored from a plugin template `reference/command-templates/fix.template.md`. It mirrors `/d:task`: the main agent is the conductor, dispatches the Phase 1 `d-*` agents via the Task tool, reads the manifest at runtime for roster + gate commands, and reuses the shared `reference/reflow.md` (authored in Phase 2). The defining difference from `/d:task` is **root-cause-first**: no fix is written until `d-tester` produces a diagnosis and the user confirms it (symmetric with `/d:task`'s spec checkpoint), and verification centers on a **regression test** that reproduces the bug.

**Tech Stack:** Claude Code plugin (markdown command + reference docs), the Phase 1 manifest + agents, the Phase 2 `reference/reflow.md`, `git`. No application runtime — verification is dogfooding against the Phase 1 fixture after running `/d:init`.

**Adaptation note:** Same as Phases 1–2 — prompt engineering. "Tests" are structure/JSON checks plus a fixture dogfood: run `/d:init` (now also generates `/d:fix`), confirm `/d:fix` is well-formed, then simulate a `/d:fix` run (auto-answering the diagnosis checkpoint) and assert the loop produces a diagnosis, routes a fix, adds a regression test, runs the gates, reflows, and records.

**Depends on:** Phases 1 & 2 (both merged to `main`). This branch is based off `main`.

---

## File Structure

- Create: `reference/command-templates/fix.template.md` — the body authored into `<target>/.claude/commands/d/fix.md`.
- Modify: `commands/init.md` — add a generation step (after the Step 10 that generates `/d:task`) that writes `<target>/.claude/commands/d/fix.md` from the template; renumber subsequent steps; update summary.
- Modify: `tests/CHECKLIST.md` — add assertions that `/d:fix` is generated and valid.
- Create: `tests/CHECKLIST-fix.md` — the expected-behavior checklist for a simulated `/d:fix` run.

(No new reflow doc — `reference/reflow.md` from Phase 2 is reused as-is.)

Placeholder convention: `{{SLOT}}` = a value `/d:init` fills at generation. Keep slots minimal — prefer reading from the manifest at runtime. `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` is a generation-time substitution token (expanded to an absolute path), exactly as in the `/d:task` template.

---

## Task 1: `/d:fix` command template

The heart of Phase 3.

**Files:**
- Create: `reference/command-templates/fix.template.md`

- [ ] **Step 1: Write the template**

Create `reference/command-templates/fix.template.md` with EXACTLY this content (YAML frontmatter then body):

````markdown
---
description: Diagnose and fix a bug in {{PROJECT_NAME}} — root cause first, then a verified fix
argument-hint: <bug description>
---

You are running `/d:fix` — the bug-fix conductor for **{{PROJECT_NAME}}**.
You are the conductor: you dispatch the project's `d-*` subagents via the Task tool and drive the loop.
Subagents cannot dispatch other subagents — all orchestration is yours.

First, READ `.claude/d/manifest.json` to load: `roles`, `qualityGate`, `testGate`, `uiBaseline`, `stack`, `specCounter`.
The bug report is in `$ARGUMENTS`.

## Step 1 — Root-cause investigation (d-tester)

Dispatch the `d-tester` subagent with the bug report. It must:
- reproduce the bug (establish a concrete failing scenario),
- find the **root cause** — no fix without a root cause; if the cause is unclear, keep investigating, do not guess,
- (opportunistically use the `systematic-debugging` skill if it is available),
- return a written **diagnosis**: reproduction steps, the root cause, the affected files/layer, and a proposed fix approach.

## ⏸ Step 2 — DIAGNOSIS CHECKPOINT (REQUIRED HUMAN STOP)

**STOP and show the user the diagnosis.** Do NOT write any fix until the user confirms.
Present the reproduction, the root cause, and the proposed fix approach; ask the user to confirm or correct (use AskUserQuestion or an explicit "⏸ Confirm the diagnosis, or tell me what to change."). This is symmetric with `/d:task`'s spec checkpoint. Re-dispatch `d-tester` to refine until the user confirms.

## Step 3 — Route the fix (owning worker)

From the root cause's layer, route the fix to its owning agent (`d-frontend` and/or `d-backend`). Dispatch that worker to implement the confirmed fix, honoring the inlined conventions. Keep the fix minimal and targeted at the root cause.

## Step 4 — Verify (regression test + gates)

- `d-tester`: add a **regression test** that reproduces the bug — it must FAIL on the pre-fix behavior and PASS after the fix — then run `testGate.test`.
- `d-reviewer`: run the quality gate (`qualityGate.lint` + `qualityGate.format` + `qualityGate.typecheck` + any `qualityGate.extra`).
- Visual gate (ONLY if `d-ui` in roles and the bug is visual): `d-ui` runs the visual diff.

Each gate's verdict is its **script exit status**, never a subjective call.

## Step 5 — Reject loop (max 3 rounds)

If any gate FAILS: send the failing report back to the owning worker to fix, then re-run the failing gate(s). A gate whose own script/config is broken is fixed by its owner (`d-tester`/`d-reviewer`/`d-ui`), not counted against the worker. **If the fix fails a gate 3 times, STOP and escalate to the user** with the failure detail and your diagnosis.

## Step 6 — Reflow

When all gates pass: READ `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` and perform knowledge reflow — the root cause and any newly discovered pitfall are prime candidates. Apply the durability bar and dispatch `d-pm` (and `d-ui` for UI learnings) to integrate durable learnings into `docs/conventions.md` / `docs/architecture/` (lean, edit-in-place). Auto-commit the doc updates.

## Step 7 — Record + report

Record a lightweight note to `docs/specs/NNNN-fix-<slug>/` (NNNN = zero-padded `specCounter` + 1; bump `specCounter` in the manifest) capturing the bug, root cause, and fix. Then print a final report: the root cause, the fix, the regression test, the gate results, any 3-round escalation, and **which docs were reflowed**.
````

Note (same mechanism as `/d:task`): when `/d:init` writes this into `<target>/.claude/commands/d/fix.md`, it fills `{{PROJECT_NAME}}` and expands `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` to the absolute plugin path so the generated command is self-contained.

- [ ] **Step 2: Verify the template structure**

Run: `cd /Users/dudu/cc-commands && grep -E "DIAGNOSIS CHECKPOINT|root cause|regression test|3 times|reflow|manifest.json" reference/command-templates/fix.template.md | wc -l`
Expected: count ≥ 5.

Run: `cd /Users/dudu/cc-commands && head -1 reference/command-templates/fix.template.md`
Expected: `---`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add reference/command-templates/fix.template.md && git commit -m "feat(d): /d:fix command template"
```

---

## Task 2: Wire `/d:init` to generate `/d:fix`

**Files:**
- Modify: `commands/init.md`

- [ ] **Step 1: Read the current step layout**

`commands/init.md` currently has (post-Phase-2): Step 9 GENERATE AGENTS, Step 10 GENERATE THE `/d:task` COMMAND, Step 11 GREEN-BASELINE, Step 12 WRITE MANIFEST, Step 13 SUMMARY. Read the file to capture exact wording.

- [ ] **Step 2: Add the `/d:fix` generation step**

Insert a new step **immediately after Step 10** (the `/d:task` generation) that mirrors it for `/d:fix`:
- Read `${CLAUDE_PLUGIN_ROOT}/reference/command-templates/fix.template.md`.
- Fill `{{PROJECT_NAME}}` (and any other `{{SLOT}}`) from extracted/confirmed data.
- Expand the literal `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` token to the absolute resolved path to the plugin's `reference/reflow.md`.
- Write to `<target>/.claude/commands/d/fix.md` (the `d/` subdirectory is required so it's invoked as `/d:fix`).
- Hard requirement: no `{{SLOT}}` and no unexpanded `${CLAUDE_PLUGIN_ROOT}` may remain.

Renumber the subsequent steps: GREEN-BASELINE → Step 12, WRITE MANIFEST → Step 13, SUMMARY → Step 14. Keep the `🟢` marker on green-baseline and the `⏸` marker on the Step 8 calibration checkpoint. Update any cross-references (e.g. "run Steps 3–13" → "3–14"). Keep the command-naming HTML comment intact.

Update the SUMMARY step so it lists BOTH generated commands (`.claude/commands/d/task.md` and `.claude/commands/d/fix.md`) and notes that `/d:task` and `/d:fix` are now available (remove the "/d:fix lands in a later plan" note).

- [ ] **Step 3: Verify**

Run: `cd /Users/dudu/cc-commands && grep -E "fix.template.md|commands/d/fix.md" commands/init.md | wc -l`
Expected: count ≥ 2.

Run: `cd /Users/dudu/cc-commands && grep -E "^## .*Step " commands/init.md`
Expected: step numbers sequential 1–14, no duplicates/gaps.

Run: `cd /Users/dudu/cc-commands && grep -c "command-naming" commands/init.md`
Expected: 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/dudu/cc-commands && git add commands/init.md && git commit -m "feat(d): /d:init generates project-local /d:fix command"
```

---

## Task 3: Update dogfood checklists

**Files:**
- Modify: `tests/CHECKLIST.md`
- Create: `tests/CHECKLIST-fix.md`

- [ ] **Step 1: Extend the /d:init checklist**

Append to `tests/CHECKLIST.md`:
```markdown
- [ ] .claude/commands/d/fix.md was generated, starts with valid `---` frontmatter, and contains no remaining {{SLOTS}}
- [ ] the generated fix.md references reading .claude/d/manifest.json and an absolute path to the plugin's reference/reflow.md (not a bare ${CLAUDE_PLUGIN_ROOT})
```

- [ ] **Step 2: Write the /d:fix behavior checklist**

Create `tests/CHECKLIST-fix.md`:
```markdown
# /d:fix simulated-run checklist

Run after /d:init, on a trivial bug (e.g. "/health returns ok:false instead of ok:true").

- [ ] d-tester produced a diagnosis with reproduction + root cause before any fix was written
- [ ] a DIAGNOSIS CHECKPOINT was presented and confirmed before implementation (human stop)
- [ ] the fix was routed to the owning worker (d-backend for the /health bug) and is minimal/targeted
- [ ] d-tester added a regression test that reproduces the bug (fails pre-fix, passes post-fix)
- [ ] the test gate and quality gate each ran and reported pass/fail by script exit status
- [ ] on all-pass, a reflow step ran (root cause is a prime candidate) and the report listed which docs (if any) were reflowed
- [ ] a lightweight record was written to docs/specs/NNNN-fix-<slug>/ and specCounter bumped
- [ ] final report includes root cause, the fix, regression test, and gate results
```

- [ ] **Step 3: Verify both files**

Run: `cd /Users/dudu/cc-commands && ls tests/CHECKLIST.md tests/CHECKLIST-fix.md && grep -c "fix.md" tests/CHECKLIST.md`
Expected: both listed, count ≥ 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/dudu/cc-commands && git add tests/CHECKLIST.md tests/CHECKLIST-fix.md && git commit -m "test(d): dogfood checklists for /d:fix generation + run"
```

---

## Task 4: End-to-end dogfood (generation + simulated run)

**Files:**
- Uses: plugin repo + `tests/fixtures/sample-fullstack`

- [ ] **Step 1: Scratch copy + simulate /d:init**

Copy `tests/fixtures/sample-fullstack` to `/tmp/d-dogfood3`, `git init`, commit. Act out `commands/init.md` against it (substitute `${CLAUDE_PLUGIN_ROOT}` → `/Users/dudu/cc-commands`), auto-confirm the calibration checkpoint, choose "AI decides UI". This must now generate BOTH `.claude/commands/d/task.md` AND `.claude/commands/d/fix.md`, plus the manifest, docs, and agents.

- [ ] **Step 2: Verify /d:fix was generated**

Run:
```bash
cd /tmp/d-dogfood3 && \
ls .claude/commands/d/fix.md && head -1 .claude/commands/d/fix.md && \
( grep -q "{{" .claude/commands/d/fix.md && echo "FAIL: slots remain" || echo "OK: no slots" ) && \
( grep -q 'manifest.json' .claude/commands/d/fix.md && echo "OK: reads manifest" || echo "FAIL" ) && \
( grep -q '${CLAUDE_PLUGIN_ROOT}' .claude/commands/d/fix.md && echo "FAIL: unexpanded root" || echo "OK: no unexpanded root" ) && \
( grep -qE '/Users/dudu/cc-commands/reference/reflow.md' .claude/commands/d/fix.md && echo "OK: absolute reflow path" || echo "WARN: reflow path" )
```
Expected: file exists, `---` first line, no slots, reads manifest, no unexpanded root, absolute reflow path.

- [ ] **Step 3: Simulate a /d:fix run**

Because a subagent cannot dispatch further subagents, role-play each `d-*` agent inline. To give the fix something real to do, first introduce a bug into the scratch project: edit `/tmp/d-dogfood3/src/server/index.ts` so the `/health` route returns `{ ok: false }`. Then act out `/tmp/d-dogfood3/.claude/commands/d/fix.md` with the bug report "/health returns ok:false instead of ok:true". Auto-confirm the DIAGNOSIS CHECKPOINT. Role-play: d-tester diagnoses (root cause = the route returns the wrong literal) → fix routed to d-backend (restore `{ ok: true }`) → d-tester adds a regression test → run gates (the fixture's `echo` gate stubs exit 0, acceptable for validating loop structure) → reflow → record to `docs/specs/NNNN-fix-<slug>/` → report. Walk `tests/CHECKLIST-fix.md`.

- [ ] **Step 4: Record findings**

If any step in the generated `/d:fix` command is impossible/ambiguous or produces a wrong artifact, record it as a FINDING (exact plugin file + problem + fix) and fix it in the plugin source, then re-run from Step 1. Do not paper over gaps.

- [ ] **Step 5: Clean up + commit validated state**

```bash
rm -rf /tmp/d-dogfood3 && cd /Users/dudu/cc-commands && git commit --allow-empty -m "test(d): phase 3 dogfood — /d:fix generated and loop executes on fixture"
```

---

## Self-Review (completed)

**Spec coverage (Phase 3 scope = spec §6 `/d:fix`):**
- §6 step 1 d-tester root-cause investigation (no fix without root cause, opportunistic systematic-debugging): Task 1 template Step 1 ✓
- §6 step 2 human diagnosis checkpoint (symmetric with task): Task 1 template Step 2 ✓
- §6 step 3 route fix to owning agent: Task 1 template Step 3 ✓
- §6 step 4 verify fix + regression + quality gate by script result: Task 1 template Step 4 ✓
- 3-round escalation: Task 1 template Step 5 ✓
- §6 step 5 reflow (reusing reference/reflow.md): Task 1 template Step 6 ✓
- §6 step 6 lightweight record to docs/specs/NNNN-fix-slug/ + report: Task 1 template Step 7 ✓
- generated project-local command at `.claude/commands/d/fix.md` (spec §2): Task 2 ✓
- **Deferred (out of scope):** new-project better-t-stack scaffolding + incremental refresh (Phase 4).

**Placeholder scan:** the only `{{SLOT}}` is `{{PROJECT_NAME}}` (filled at generation, asserted gone in Task 4 Step 2). `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` is a generation-time substitution token, asserted expanded to an absolute path in Task 4. No "TBD/handle edge cases" steps.

**Type/name consistency:** manifest fields (`roles`, `qualityGate`, `testGate`, `uiBaseline`, `specCounter`) and agent names (`d-pm`/`d-tester`/`d-ui`/`d-reviewer`/`d-frontend`/`d-backend`) match Phases 1–2 and the manifest reference. The generated path `.claude/commands/d/fix.md` and spec numbering `docs/specs/NNNN-fix-<slug>/` with pre-incremented `specCounter` are consistent across Tasks 1, 2, 4. The reflow reuse points at the same `reference/reflow.md` consumed by `/d:task`.

---

## Next plan

- **Plan 4 — new project + refresh:** `reference/better-t-stack.md`, the new-project scaffolding branch in `commands/init.md` (replace the Step 2 "lands in a later plan" stub), and the incremental-refresh mode (spec §3.1, §3.3) with lean-docs consolidation. After Plan 4, the full spec is implemented.
