# d Plugin — Phase 5: Commit & PR Convention — Implementation Plan

> **For agentic workers:** Small, focused enhancement. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the commit/PR format a recorded **project convention** so every future auto-commit by `d` agents (reflow, fixes, doc updates) is consistent. Light-touch: detect-or-default to Conventional Commits, record it in `docs/conventions.md`, and have the committing agents follow it — no commitlint config or git hook (the heavier "mechanical gate" option was explicitly declined).

**Architecture:** Commit/PR convention is just another entry in the code source of truth (`docs/conventions.md`). `/d:init` detects an existing convention (commitlint config / CONTRIBUTING / git history) or defaults to Conventional Commits, and writes a `## Commit & PR Conventions` section. Every command/agent that commits already reads `docs/conventions.md`, so they follow it; the commit sites (reflow, the two command templates) point at the section explicitly.

**Depends on:** Phases 1–4 (merged to `main`).

---

## Changes (all in existing plugin files)

- `reference/conventions-extraction.md`
  - New subsection **"Commit & PR conventions"** under Step 1: detect-or-default (config → docs → git history → Conventional Commits), light-touch (no hook/config authored).
  - New required output section `## Commit & PR Conventions` in the generated `docs/conventions.md` structure.
- `reference/reflow.md` — the auto-commit step explicitly follows the `Commit & PR Conventions` section.
- `reference/command-templates/task.template.md` — preamble rule: every commit this run follows the convention.
- `reference/command-templates/fix.template.md` — same preamble rule.
- `tests/CHECKLIST.md` — assert the generated `docs/conventions.md` has a `Commit & PR Conventions` section.

---

## Task 1: Record commit/PR convention in conventions extraction

- [x] Add the **"Commit & PR conventions"** detect-or-default subsection to `reference/conventions-extraction.md` Step 1.
- [x] Add the `## Commit & PR Conventions` section to the required output structure in Step 4.

## Task 2: Point the commit sites at the convention

- [x] `reference/reflow.md`: the conductor's auto-commit follows the `Commit & PR Conventions` section (Conventional Commits by default).
- [x] `reference/command-templates/task.template.md`: add preamble "every commit follows the convention".
- [x] `reference/command-templates/fix.template.md`: same preamble.

## Task 3: Dogfood assertion

- [x] `tests/CHECKLIST.md`: add the Phase 5 assertion that `docs/conventions.md` contains a `Commit & PR Conventions` section.

---

## Verification

This is a doc/prompt-only change to the conventions pipeline already exercised by the Phase 1–4 dogfoods. Internal consistency checked: the section name `Commit & PR Conventions` matches across `conventions-extraction.md`, `reflow.md`, and both command templates; no agent renamed; default is Conventional Commits with the standard type set.

**Interactive acceptance:** on the next live `/d:init`, confirm the generated `docs/conventions.md` includes the `Commit & PR Conventions` section and that a subsequent `/d:task`/`/d:fix` reflow commit uses the recorded format.

---

## Self-Review

- **Scope:** commit/PR convention is recorded and followed; mechanical enforcement (commitlint/hook/PR-title action) intentionally OUT of scope per the chosen option.
- **Consistency:** section name + default (Conventional Commits) identical across all touched files; commit message example in `reflow.md` (`docs: reflow after <id>`) is already Conventional-compliant.
- **No placeholders / no renamed agents** (verified `d-tester` header intact in `fix.template.md`).
