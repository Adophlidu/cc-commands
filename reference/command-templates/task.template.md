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
