# d Plugin — Phase 2: `/d:task` Iteration Workflow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/d:init` generate a project-local `/d:task` command, and author the `/d:task` orchestration that drives the requirement-iteration loop: PM decomposes a requirement into a numbered spec + API contract → human spec checkpoint → tester/ui generate acceptance scripts (PM coverage-gates them) → workers implement → three parallel gates (quality / test / visual) judge by script result → reject loop with 3-round escalation → knowledge reflow → report.

**Architecture:** `/d:task` is a *generated, project-local* command at `<target>/.claude/commands/d/task.md` (the `d/` subdirectory yields the `/d:task` invocation). Its body is authored from a plugin template `reference/command-templates/task.template.md`. The generated command reads `<target>/.claude/d/manifest.json` at runtime for the role roster and the verified gate commands (DRY — no hardcoding that can drift). The main agent running `/d:task` is the conductor (subagents can't dispatch subagents); it dispatches the Phase 1 agents (`d-pm`, `d-frontend`, `d-backend`, `d-tester`, `d-ui`, `d-reviewer`) via the Task tool and coordinates the loop. Knowledge reflow (spec §7) is a shared step authored once in `reference/reflow.md` and invoked by `/d:task` (and later `/d:fix`).

**Tech Stack:** Claude Code plugin (markdown command + reference docs), the Phase 1 manifest + agents, `git`. No application runtime — verification is dogfooding against the Phase 1 fixture after running `/d:init`.

**Adaptation note:** Same as Phase 1 — this is prompt engineering. "Tests" are structure/JSON checks plus a fixture dogfood: run `/d:init` on the fixture, confirm `/d:task` is generated and well-formed, then simulate a `/d:task` run (auto-answering the human checkpoint) and assert the loop produces a spec, runs the three gates, and reflows.

**Depends on:** Phase 1 (branch `feat/d-plugin-phase1`, PR #1). This plan's branch is based off it.

---

## File Structure

- Create: `reference/reflow.md` — the knowledge-reflow mechanism (candidate learnings → durability bar → doc-owner edits, lean discipline). Shared by `/d:task` and `/d:fix`.
- Create: `reference/command-templates/task.template.md` — the body authored into `<target>/.claude/commands/d/task.md`.
- Modify: `commands/init.md` — add a generation step (after agent generation) that writes `<target>/.claude/commands/d/task.md` from the template; mention it in the summary.
- Modify: `tests/CHECKLIST.md` — add assertions that `/d:task` is generated and valid.
- Create: `tests/CHECKLIST-task.md` — the expected-behavior checklist for a simulated `/d:task` run.

Placeholder convention (same as Phase 1): `{{SLOT}}` = a value `/d:init` fills when generating the command. Keep slots minimal — prefer "read it from the manifest at runtime" over baking values in.

---

## Task 1: Knowledge-reflow reference

Authored once, used by `/d:task` (this plan) and `/d:fix` (Phase 3). Implements spec §7.

**Files:**
- Create: `reference/reflow.md`

- [ ] **Step 1: Write the reflow guide**

`reference/reflow.md` must specify:
- **When it runs**: at the end of a `/d:task` or `/d:fix` run, after all gates pass.
- **Inputs**: the "candidate learnings" surfaced by worker/tester/ui agents in their returned reports during the run (architecture changes, new pitfalls, new conventions, better UI approaches).
- **Durability bar (noise filter)**: a candidate is codified only if all three hold — ① general (will recur), ② not already in the docs (dedupe), ③ stable (not a one-off). Otherwise drop it.
- **Doc owners / routing**: architecture changes + new pitfalls + new conventions → `d-pm` integrates into `docs/architecture/` and `docs/conventions.md`. Better UI approaches → `d-ui` integrates into `docs/design.md` — UNLESS `uiBaseline.designSource` is an external tool (Figma/Stitch), in which case the UI learning is reported for the user to reflect in the external tool and `docs/design.md` is NOT created.
- **Lean discipline (edit, don't append)**: integrate in place, supersede/prune stale entries, never keep new+old of a contradiction, history lives in git not in the doc.
- **Auto-commit + surface**: doc updates are committed automatically; the `/d:task` final report lists exactly which docs were reflowed. No extra human checkpoint.
- Note that the conductor (main agent) dispatches `d-pm`/`d-ui` to perform the integration (they are the doc owners with Write access under `docs/`).

- [ ] **Step 2: Verify required content**

Run: `cd /Users/dudu/cc-commands && grep -E "durability|d-pm|d-ui|designSource|supersede|candidate" reference/reflow.md | wc -l`
Expected: count ≥ 5.

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add reference/reflow.md && git commit -m "docs(d): knowledge-reflow reference (shared by task/fix)"
```

---

## Task 2: `/d:task` command template

The heart of Phase 2 — the generated command body.

**Files:**
- Create: `reference/command-templates/task.template.md`

- [ ] **Step 1: Write the template**

Create `reference/command-templates/task.template.md` with YAML frontmatter and a body. EXACT content:

````markdown
---
description: Iterate a requirement for {{PROJECT_NAME}} — PM specs it, agents build it, three gates verify it
argument-hint: <requirement description>
---

You are running `/d:task` — the requirement-iteration conductor for **{{PROJECT_NAME}}**.
You are the conductor: you dispatch the project's `d-*` subagents via the Task tool and drive the loop.
Subagents cannot dispatch other subagents — all orchestration is yours.

First, READ `.claude/d/manifest.json` to load: `roles`, `qualityGate`, `testGate`, `uiBaseline`, `stack`, `specCounter`.
The requirement is in `$ARGUMENTS`.

## Step 1 — Decompose (d-pm)

Dispatch the `d-pm` subagent with the requirement. It must:
- read `docs/architecture/overview.md` + `docs/conventions.md`,
- compute the next spec number `NNNN` = zero-padded (`specCounter` + 1),
- write `docs/specs/NNNN-<slug>/spec.md` with: sub-task breakdown, acceptance criteria, owning agent per sub-task, and an explicit **API contract** (endpoints / inputs / outputs / errors) when both a frontend and a backend role are involved,
- bump `specCounter` to `NNNN` in `.claude/d/manifest.json`.

## ⏸ Step 2 — SPEC CHECKPOINT (REQUIRED HUMAN STOP)

**STOP and show the user the spec.** Do NOT start implementation until the user approves.
Present the sub-task breakdown, acceptance criteria, and API contract; ask the user to approve or request changes (use AskUserQuestion or an explicit "⏸ Approve, or tell me what to change."). Apply changes (re-dispatch `d-pm`) until approved.

## Step 3 — Generate acceptance scripts (d-tester + d-ui, parallel)

In parallel, dispatch:
- `d-tester`: turn each acceptance criterion into real test cases using the test framework (test command from `testGate.test`).
- `d-ui` (ONLY if `d-ui` in roles): generate/refresh the visual-regression scenarios for the spec, per `uiBaseline` (compare vs `designSource`, or establish/refresh the regression baseline when `mode` is `regression`).

(The `d-reviewer` quality gate needs no per-task generation — its rules were fixed at `/d:init`.)

## Step 4 — Coverage gate (d-pm)

Dispatch `d-pm` to review the generated tests/visual scenarios against the spec. If coverage is insufficient, send back to `d-tester`/`d-ui` to extend (this is an automatic gate — do NOT involve the user). Loop until `d-pm` approves coverage.

## Step 5 — Implement (workers)

For each sub-task, dispatch its owning agent (`d-frontend` and/or `d-backend`). Independent sub-tasks may be dispatched in parallel; sub-tasks that share files must be sequenced. Workers honor the API contract exactly and obey the inlined conventions.

## Step 6 — Three gates (judge by script result)

Run all applicable gates; the verdict of each is its **script exit status**, never a subjective call:
- **Quality gate** — dispatch `d-reviewer` to run `qualityGate.lint` + `qualityGate.format` + `qualityGate.typecheck` (+ any `qualityGate.extra`).
- **Test gate** — dispatch `d-tester` to run `testGate.test`.
- **Visual gate** — (if `d-ui` in roles) dispatch `d-ui` to run the visual diff.

## Step 7 — Reject loop (max 3 rounds per sub-task)

If any gate FAILS: send the failing report back to the owning worker to fix, then re-run the failing gate(s). A gate whose own script/config is broken is fixed by the gate's owner (`d-tester`/`d-ui`/`d-reviewer`), not counted against the worker.

Track per-sub-task reject rounds. **If the same sub-task fails a gate 3 times, STOP and escalate to the user** with the failure detail and your diagnosis — do not loop further.

## Step 8 — Reflow

When all gates pass: READ `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` and perform knowledge reflow — collect the candidate learnings surfaced by the agents this run, apply the durability bar, and dispatch `d-pm` / `d-ui` to integrate durable learnings into the docs (lean, edit-in-place). Auto-commit the doc updates.

## Step 9 — Report

Print a final report: the spec path, what each worker changed, the three-gate results, any 3-round escalations, and **which docs were reflowed**. Update the spec's status to done.
````

Note on `${CLAUDE_PLUGIN_ROOT}` in the GENERATED command: when this template is written into `<target>/.claude/commands/d/task.md`, the `reference/reflow.md` path must resolve to the *plugin's* copy. During generation (Task 3), `/d:init` replaces `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` with the absolute resolved path to the installed plugin's `reference/reflow.md` so the generated command needs no env var. (Task 3 handles this substitution.)

- [ ] **Step 2: Verify the template structure**

Run: `cd /Users/dudu/cc-commands && grep -E "SPEC CHECKPOINT|three gates|reject loop|3 times|reflow|manifest.json" reference/command-templates/task.template.md | wc -l`
Expected: count ≥ 5.

Run: `cd /Users/dudu/cc-commands && head -1 reference/command-templates/task.template.md`
Expected: `---` (valid frontmatter).

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add reference/command-templates/task.template.md && git commit -m "feat(d): /d:task command template"
```

---

## Task 3: Wire `/d:init` to generate `/d:task`

Add the generation step to the orchestrator so a real `<target>/.claude/commands/d/task.md` is produced.

**Files:**
- Modify: `commands/init.md` (add a step between Step 9 "Generate agents" and the manifest/summary; renumber as needed)

- [ ] **Step 1: Add the command-generation step**

Insert a new step in `commands/init.md` (after agent generation, before/with the manifest write) that instructs the agent to:
- Read `${CLAUDE_PLUGIN_ROOT}/reference/command-templates/task.template.md`.
- Fill `{{PROJECT_NAME}}` and any other slots from extracted data.
- Replace the literal token `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` inside the template body with the absolute resolved path to the plugin's `reference/reflow.md` (so the generated command is self-contained and does not depend on the env var being set in the target project's future sessions).
- Write the result to `<target>/.claude/commands/d/task.md` (the `d/` subdirectory is required so the command is invoked as `/d:task`).
- Note in the summary that `/d:task` is now available in the project (and `/d:fix` lands in a later plan).

The new-project / already-initialized STOP behaviors are unchanged.

- [ ] **Step 2: Verify init references the template and the generated path**

Run: `cd /Users/dudu/cc-commands && grep -E "task.template.md|commands/d/task.md" commands/init.md | wc -l`
Expected: count ≥ 2.

- [ ] **Step 3: Commit**

```bash
cd /Users/dudu/cc-commands && git add commands/init.md && git commit -m "feat(d): /d:init generates project-local /d:task command"
```

---

## Task 4: Update dogfood checklists

**Files:**
- Modify: `tests/CHECKLIST.md`
- Create: `tests/CHECKLIST-task.md`

- [ ] **Step 1: Extend the /d:init checklist**

Append to `tests/CHECKLIST.md`:
```markdown
- [ ] .claude/commands/d/task.md was generated, starts with valid `---` frontmatter, and contains no remaining {{SLOTS}}
- [ ] the generated task.md references reading .claude/d/manifest.json and an absolute path to the plugin's reference/reflow.md (not a bare ${CLAUDE_PLUGIN_ROOT})
```

- [ ] **Step 2: Write the /d:task behavior checklist**

Create `tests/CHECKLIST-task.md`:
```markdown
# /d:task simulated-run checklist

Run after /d:init, on a trivial requirement (e.g. "add a /version endpoint returning the app version").

- [ ] d-pm wrote docs/specs/0001-<slug>/spec.md with sub-tasks, acceptance criteria, and (since fullstack) an API contract
- [ ] manifest specCounter bumped to 1
- [ ] a SPEC CHECKPOINT was presented before any implementation (human stop)
- [ ] d-tester produced real test cases for the acceptance criteria
- [ ] the three gates each ran and reported pass/fail by script exit status
- [ ] on all-pass, a reflow step ran and the report listed which docs (if any) were reflowed
- [ ] final report includes spec path, changes, three-gate results
```

- [ ] **Step 3: Verify both files exist**

Run: `cd /Users/dudu/cc-commands && ls tests/CHECKLIST.md tests/CHECKLIST-task.md && grep -c "task.md" tests/CHECKLIST.md`
Expected: both listed, count ≥ 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/dudu/cc-commands && git add tests/CHECKLIST.md tests/CHECKLIST-task.md && git commit -m "test(d): dogfood checklists for /d:task generation + run"
```

---

## Task 5: End-to-end dogfood (generation + simulated run)

**Files:**
- Uses: plugin repo + `tests/fixtures/sample-fullstack`

- [ ] **Step 1: Scratch copy + run /d:init (simulated)**

Per Phase 1's dogfood method: copy `tests/fixtures/sample-fullstack` to `/tmp/d-dogfood2`, `git init`, commit. Then act out `commands/init.md` against it (substituting `${CLAUDE_PLUGIN_ROOT}` → `/Users/dudu/cc-commands`), auto-answering the calibration checkpoint and choosing "AI decides UI". This must now ALSO generate `/tmp/d-dogfood2/.claude/commands/d/task.md`.

- [ ] **Step 2: Verify /d:task was generated**

Run:
```bash
cd /tmp/d-dogfood2 && \
ls .claude/commands/d/task.md && \
head -1 .claude/commands/d/task.md && \
( grep -q "{{" .claude/commands/d/task.md && echo "FAIL: slots remain" || echo "OK: no slots" ) && \
( grep -q 'manifest.json' .claude/commands/d/task.md && echo "OK: reads manifest" || echo "FAIL: no manifest read" ) && \
( grep -qE '/Users/.*reference/reflow.md' .claude/commands/d/task.md && echo "OK: absolute reflow path" || echo "WARN: check reflow path" )
```
Expected: file exists, `---` first line, no slots, reads manifest, absolute reflow path.

- [ ] **Step 3: Simulate a /d:task run**

Act out `/tmp/d-dogfood2/.claude/commands/d/task.md` with the requirement "add a /version endpoint returning the app version". Auto-approve the SPEC CHECKPOINT. Since the fixture's gate scripts are `echo` stubs (exit 0), the three gates pass trivially — that is acceptable for validating the LOOP STRUCTURE (the point is that pm→checkpoint→generate→implement→3 gates→reflow→report all execute in order). Walk `tests/CHECKLIST-task.md`.

- [ ] **Step 4: Record findings**

If any step in the generated command is impossible to follow, ambiguous, or produces a wrong artifact, record it as a FINDING (exact file + problem + fix) rather than papering over it. Fix findings in the plugin source (`reference/...` or `commands/init.md`) and re-run from Step 1.

- [ ] **Step 5: Clean up + commit the validated state**

```bash
rm -rf /tmp/d-dogfood2 && cd /Users/dudu/cc-commands && git commit --allow-empty -m "test(d): phase 2 dogfood — /d:task generated and loop executes on fixture"
```

---

## Self-Review (completed)

**Spec coverage (Phase 2 scope = spec §5 `/d:task` + §7 reflow):**
- §5 step 1 pm decompose → spec + API contract: Task 2 Step 1 (template Step 1) ✓
- §5 step 2 human spec checkpoint: template Step 2 ✓
- §5 step 3 tester/ui generate cases: template Step 3 ✓
- §5 step 4 pm coverage gate: template Step 4 ✓
- §5 step 5 parallel implement + contract-first: template Step 5 ✓
- §5 step 6 three parallel gates by script result: template Step 6 ✓
- §5 step 7 reject loop + 3-round escalation: template Step 7 ✓
- §5 step 8 reflow: template Step 8 + Task 1 ✓
- §5 step 9 report + spec status: template Step 9 ✓
- §7 reflow (durability bar, doc owners, lean, auto-commit+surface): Task 1 ✓
- generated project-local command at `.claude/commands/d/task.md` (spec §2): Task 3 ✓
- **Deferred (out of scope):** `/d:fix` (Phase 3), new-project + refresh (Phase 4). `/d:fix` reuses `reference/reflow.md` authored here.

**Placeholder scan:** the only `{{SLOT}}` is `{{PROJECT_NAME}}` (filled at generation, asserted gone in Task 5 Step 2). `${CLAUDE_PLUGIN_ROOT}/reference/reflow.md` is a generation-time substitution token, explicitly resolved in Task 3 Step 1 and asserted absolute in Task 5. No "TBD/handle edge cases" steps.

**Type/name consistency:** manifest fields (`roles`, `qualityGate`, `testGate`, `uiBaseline`, `specCounter`) and agent names (`d-pm`/`d-tester`/`d-ui`/`d-reviewer`/`d-frontend`/`d-backend`) match Phase 1 and the manifest reference. The generated command path `.claude/commands/d/task.md` is consistent across Tasks 3, 4, 5. Spec numbering `docs/specs/NNNN-<slug>/spec.md` with pre-incremented `specCounter` matches the Phase 1 manifest reference fix.

---

## Next plan

- **Plan 3 — `/d:fix`:** `reference/command-templates/fix.template.md` (root-cause checkpoint → routed fix → regression + quality gate → reflow via the shared `reference/reflow.md`); `/d:init` generates `.claude/commands/d/fix.md`. Spec §6.
- **Plan 4 — new project + refresh:** better-t-stack scaffolding branch + incremental-refresh mode (spec §3.1, §3.3).
