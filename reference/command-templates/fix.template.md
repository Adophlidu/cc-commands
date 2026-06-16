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
