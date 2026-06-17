# d Plugin — Phase 7: Branch Discipline (never commit to trunk) — Implementation Plan

> **For agentic workers:** Focused enhancement. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Enforce a PR-based git workflow: `/d:task` and `/d:fix` always work on a branch off the trunk and **never commit directly to the trunk**; each run finishes by opening a PR. `/d:init` asks which branch is the trunk (default `main`) and records it.

**Decisions (chosen by the user):**
- Branch naming: `/d:task` → `d/task/<NNNN-slug>` (spec number + slug); `/d:fix` → `d/fix/<slug>`. Follow a detected project branch convention if one exists.
- Finish: open a PR if a remote + `gh` exist; else push + print PR instructions; else leave the local branch.
- Trunk: asked at `/d:init`, default `main`, stored in `manifest.trunkBranch`.

**Depends on:** Phases 1–6 (all merged to `main`). Built on `origin/main`.

---

## Changes

- `reference/manifest.md` — new `trunkBranch` field (default `main`) + semantics.
- `reference/conventions-extraction.md` — the Commit & PR section now also records **branch discipline** (trunk, never-commit-to-trunk, branch naming, finish-via-PR); the generated `## Commit & PR Conventions` section comment includes it.
- `commands/init.md` — Step 8 calibration asks the trunk branch (default `main`); Step 13 writes `trunkBranch` to the manifest.
- `reference/command-templates/task.template.md` — new **Step 0** (branch off trunk; never work on trunk; compute `NNNN-slug` used by both the branch and the spec) + new **Step 10** (open PR into trunk). Manifest load includes `trunkBranch`.
- `reference/command-templates/fix.template.md` — new **Step 0** (branch `d/fix/<slug>`) + new **Step 8** (open PR into trunk). Manifest load includes `trunkBranch`.
- `tests/CHECKLIST.md`, `CHECKLIST-task.md`, `CHECKLIST-fix.md` — assertions for trunk recording, branch-first, and PR finish.

## Tasks

- [x] Add `trunkBranch` to the manifest schema + semantics.
- [x] Record branch discipline in `conventions-extraction.md` (detect-or-default + output section).
- [x] `/d:init`: ask trunk at calibration (Step 8); write `trunkBranch` (Step 13).
- [x] `/d:task` template: Step 0 branch-first guard + Step 10 PR; load `trunkBranch`.
- [x] `/d:fix` template: Step 0 branch-first guard + Step 8 PR; load `trunkBranch`.
- [x] Update the three dogfood checklists.
- [ ] Dogfood: simulate `/d:init` (records trunk) → `/d:task` creates the branch before any commit, never commits to trunk, attempts PR/push at the end.

## Verification

- Internal consistency: `trunkBranch` present in manifest/init/both templates/conventions; branch naming `d/task/`·`d/fix/` present; never-commit-to-trunk rule in both templates; init steps 1–15; task steps 0–10; fix steps 0–8; only `{{PROJECT_NAME}}` slots remain.
- **Interactive acceptance:** on a live `/d:init` set a trunk; run `/d:task`/`/d:fix` and confirm a `d/...` branch is created off trunk, no commit lands on trunk, and a PR is opened (or push + instructions printed).

## Self-Review

- **Scope:** branch + PR discipline for task/fix; `/d:init`'s own setup commits are unchanged (it's one-time setup, not a requirement/bug-fix).
- **Edge cases addressed:** dirty working tree (ask to stash/commit); already on a work branch (stay); on trunk (must branch); no remote/gh (push+instructions or local-only).
- **Consistency:** the `NNNN-slug` is computed in Step 0 and reused by d-pm's spec dir so branch and spec match; PR body follows the Phase 5 PR convention.
