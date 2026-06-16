# analyze-codebase

Instructs `/d:init` how to analyze an existing codebase and produce architecture documentation in the target project.

## Output Location

All files go to `docs/architecture/` in the target project root.

---

## Step 1 — Measure the Repo

Before writing anything, count top-level source directories and total file count:

```
find . -maxdepth 1 -type d | grep -v '^\.$' | wc -l
find . -type f | wc -l
```

**Heuristics:**

| Signal | Classification |
|---|---|
| ≤ 5 top-level modules AND < 500 files | Small |
| > 5 top-level modules OR ≥ 500 files | Large |

---

## Step 2A — Small Repo: Single-Pass

Read enough of the codebase to fill in every field below, then write one file: `docs/architecture/overview.md`.

No per-module files are needed unless a module is clearly non-trivial (see Step 2B criteria).

---

## Step 2B — Large Repo: Parallel Exploration

Dispatch one `Explore` subagent per top-level source area (e.g. `src/api`, `src/ui`, `lib/`, `services/`, `packages/*`). Give each agent its own bounded scope:

> "Explore `src/api/`. Report: responsibility, key files with paths, public interface (exported functions/classes/routes), and dependencies on other modules. Be concrete — cite actual file paths."

Collect all reports, then:

1. Write `docs/architecture/overview.md` (same fields as small-repo case, see below).
2. Write `docs/architecture/<module>.md` for every module the Explore agents identified as non-trivial (see non-trivial criteria below).

---

## What `overview.md` Must Capture

Every field must be grounded in real files found in the repo. Do not write generic descriptions.

- **Tech stack** — languages, frameworks, and runtimes actually present (cite `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, or equivalent).
- **Layering** — how the codebase is divided (e.g. CLI → core → adapters), inferred from directory structure and import patterns.
- **Data flow** — the primary path data takes through the system, from entry point to output. Trace at least one real request or command end-to-end, citing actual file paths.
- **Entry points** — the files that bootstrap the process (e.g. `src/main.ts`, `cmd/server/main.go`, `bin/cli`). Cite the exact paths.
- **Build / run commands** — extracted from `Makefile`, `package.json` scripts, `README`, or CI config. Quote the actual commands.
- **Directory map** — a concise tree of top-level directories with a one-line description of each, grounded in what those directories actually contain.

---

## Per-Module Files (`docs/architecture/<module>.md`)

Write a per-module file only when the module is **non-trivial**, meaning it meets at least one of:

- Contains more than ~10 files with non-obvious internal structure.
- Exposes a public interface used by other modules.
- Implements domain logic that is not self-evident from file names alone.

Each per-module file must include:

- **Responsibility** — what this module does (one or two sentences grounded in actual code, not its folder name).
- **Key files** — the 3–7 most important files with their paths relative to repo root (e.g. `src/api/router.ts`, `src/api/middleware/auth.ts`).
- **Public interface** — exported functions, classes, HTTP routes, or CLI commands that other parts of the system call. Cite signatures or route paths where helpful.
- **Dependencies** — other modules or external packages this module directly imports. Cite import paths found in real files.

---

## Fit Rule (Critical)

Every statement in every architecture file must be grounded in a real file or pattern observed in the repo.

- Cite concrete paths: `src/server/index.ts`, `lib/db/models.py`, `internal/queue/worker.go`.
- If you cannot find evidence for a claim, omit the claim.
- Never write boilerplate descriptions ("handles business logic", "provides utilities") that could apply to any project.

---

## Lean Rule

Architecture docs are tight reference material, not exhaustive code dumps.

- `overview.md` should be readable in under 5 minutes.
- Per-module files should be readable in under 2 minutes each.
- Prefer bullet lists and short phrases over prose paragraphs.
- Do not reproduce source code unless a specific function signature or schema is needed to understand the interface.
