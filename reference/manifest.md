# Manifest Reference

## Location

The manifest lives at **`.claude/d/manifest.json`** inside the **target project** (not the plugin repo). Every `d` command reads from and writes to this path relative to the project root.

## Initialization detection

When `/d:init` runs, it checks for the presence of `.claude/d/manifest.json` in the target project:

- **File absent** — first-run mode: full analysis, agent generation, and manifest creation.
- **File present** — incremental-refresh mode: diff against `lastAnalyzedCommit`, update only what changed (see `reference/incremental-refresh.md`).

## JSON shape

```jsonc
{
  "version": 1,
  "initializedAt": "<ISO8601>",
  "lastAnalyzedCommit": "<git sha or null>",
  "trunkBranch": "main",
  "projectType": "fullstack | frontend | backend | cli | library",
  "stack": {
    "frontend": "<e.g. react+tanstack-router>",
    "backend": "<e.g. hono>",
    "database": "<e.g. postgres>",
    "orm": "<e.g. drizzle>",
    "test": "<e.g. vitest>",
    "pm": "<npm|pnpm|bun>"
  },
  "roles": ["d-pm", "d-frontend", "d-backend", "d-tester", "d-ui", "d-reviewer"],
  "qualityGate": {
    "lint": "<cmd or null>",
    "format": "<cmd or null>",
    "typecheck": "<cmd or null>",
    "extra": []
  },
  "testGate": {
    "test": "<cmd or null>",
    "build": "<cmd or null>"
  },
  "uiBaseline": {
    "mode": "design | regression | none",
    "designSource": "<figma url | path | docs/design.md | null>",
    "tool": "playwright | backstopjs | null"
  },
  "specCounter": 0
}
```

## Field semantics

| Field | Type | Description |
|---|---|---|
| `version` | number | Schema version. Currently `1`. Increment when the shape changes in a breaking way. |
| `initializedAt` | string | ISO 8601 timestamp of the first `/d:init` run that created this file. Never updated on refresh. |
| `lastAnalyzedCommit` | string \| null | The `HEAD` git SHA at the time of the last analysis. Used by incremental-refresh to scope the diff. `null` on projects with no commits yet. |
| `trunkBranch` | string | The project's trunk/main branch (asked at `/d:init`, default `main`). `/d:task` and `/d:fix` branch off it and **never commit directly to it** — all work lands via a PR into this branch. |
| `projectType` | enum | Classification of the project: `fullstack`, `frontend`, `backend`, `cli`, or `library`. Drives which roles are generated and which gates are relevant. |
| `stack` | object | Resolved tech stack as detected by `/d:init`. Each sub-field is a human-readable string (or `null` if not present). `pm` is the package manager (`npm`, `pnpm`, or `bun`). |
| `roles` | string[] | Which agent role files were generated under `.claude/agents/` (the path Claude Code discovers project subagents from). Subset of the full role list depending on `projectType` (e.g. no `d-frontend` or `d-ui` for a `cli` project). |
| `qualityGate` | object | Actual working commands extracted and verified by `/d:init` for lint, format, and typecheck. `null` for a gate that does not exist in the project. `extra` holds any additional project-specific quality commands. |
| `testGate` | object | Verified commands for running tests and building the project. `null` if absent. |
| `uiBaseline` | object | Controls how `d-ui` runs its visual gate. `mode: "design"` diffs against a design source; `mode: "regression"` diffs screenshots against a prior baseline; `mode: "none"` disables visual checks (no-UI projects). `designSource` is a Figma URL, a local path, or `null`. `tool` is the visual-testing driver in use. |
| `specCounter` | number | Auto-incrementing integer, starts at `0`. The next spec uses `specCounter + 1` (pre-increment), yielding zero-padded spec directories like `docs/specs/0001-auth-flow/spec.md`. The counter is bumped and persisted when the spec is created (Phase 2 owns spec creation). |
