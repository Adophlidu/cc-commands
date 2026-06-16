# incremental-refresh

Instructs `/d:init` what to do when it detects an already-initialized project — i.e., `.claude/d/manifest.json` already exists in the target project.

---

## Trigger

`/d:init` finds `.claude/d/manifest.json` at the target project root → enter incremental-refresh mode. Do **not** run the first-time generation pipeline.

---

## Step 1 — Compute the Diff

Read `manifest.lastAnalyzedCommit`. Then compute what changed since that commit:

```bash
git diff --name-only <lastAnalyzedCommit> HEAD
```

If `lastAnalyzedCommit` is `null` (project had no commits at init time), treat the full working tree as changed.

Partition the changed files into:
- **Source files** — anything under the project's source directories (`src/`, `lib/`, `app/`, `packages/`, etc.)
- **Config files** — `package.json`, `tsconfig.json`, `eslint.config.*`, `biome.json`, `.prettierrc*`, `drizzle.config.*`, `prisma/schema.prisma`, etc.
- **Documentation** — `docs/`, `CONTRIBUTING.md`, `CLAUDE.md` (project-level)

If no files changed since `lastAnalyzedCommit`, report "No changes since last analysis" and stop — skip all remaining steps, do not touch any files.

---

## Step 2 — Re-analyze Architecture (Scoped)

Re-run the architecture analysis from `reference/analyze-codebase.md`, **scoped to changed areas**:

- Only dispatch `Explore` subagents for modules that contain changed source files.
- Always re-read `docs/architecture/overview.md` — the tech-stack or entry-point sections may need updating even if the change is narrow.
- If a config file changed (e.g. `package.json`, `drizzle.config.*`), re-read that file and update the affected overview fields (stack, build/run commands, entry points).

**Update, don't recreate.** Edit the affected sections of `docs/architecture/overview.md` and the relevant per-module files in place. Follow the same Lean Rule and Fit Rule as first-time analysis:

- Supersede stale entries; remove entries for things that no longer exist.
- Never wipe-and-regenerate a file — preserve unaffected sections exactly.
- History lives in git. Write only the current truth.

---

## Step 3 — Re-extract Conventions (Scoped)

Re-run the conventions extraction from `reference/conventions-extraction.md`, **scoped to changed config and source files**:

- Re-scan only the config files listed in Step 1 that are in the changed set.
- Re-infer conventions only from source files in the changed set. Apply the same grep-verify rule: a convention must dominate the repo, not just the changed files.
- Re-query context7 only if the primary framework dependency changed in `package.json`.

**Update `docs/conventions.md` in place.** Supersede stale entries; do not append. Apply the same lean rule: bullet points, cited sources, no prose paragraphs.

---

## Step 4 — Preserve Specs

`docs/specs/*` is **never touched by refresh**. Do not read, modify, or delete any file under `docs/specs/`.

---

## Step 5 — Check Agents and Commands for Hand-edits

Agent files (`.claude/agents/d-*.md`) and generated commands (`.claude/commands/d/*.md`) may have been hand-edited by the user since init. Before refreshing any of these files:

1. **Recompute** what `/d:init` would generate now for each existing agent/command file.
2. **Diff** the recomputed output against the file on disk.
3. Classify each file as one of:
   - **Unchanged** — file on disk matches what would be generated now. Refresh silently.
   - **Content-diverged** — file on disk differs from the generated form. The user may have hand-edited it.

For every content-diverged file, **ask before writing**:

> `d-backend.md` has been modified since init. Here is what the refresh would write:
>
> ```diff
> <diff against current file>
> ```
>
> Keep current version / Replace with generated / Merge manually?

Do not overwrite without an explicit "Replace" or "Merge" answer. If the user picks "Keep", leave the file untouched and note it as preserved in the final report.

---

## Step 6 — Detect Stack/Role Drift

Compare the re-analyzed stack and `projectType` against the values stored in `manifest.stack` and `manifest.projectType`. If they differ — for example, a backend layer has been added to what was classified as a `frontend` project — this is **drift**.

On drift detected:

1. **Report** the specific change:
   > Stack drift detected: project was `frontend`, now appears to be `fullstack` (new signals: `src/api/`, `drizzle.config.ts`, `DATABASE_URL` in `.env.example`).

2. **Offer** to generate newly-needed agents and commands:
   > Offer to generate: `d-backend.md` (agent), `d-backend` commands. Generate? (y/n)

3. If the user confirms, generate the missing agents/commands using the same templates as first-time init. Do not regenerate agents/commands that already exist.

4. If the user declines, note it in the final report under "Drift — action deferred."

Do not silently update `manifest.projectType` or `manifest.roles` without user confirmation when drift is detected.

---

## Step 7 — Update Manifest

After all edits are complete, update `.claude/d/manifest.json`:

- Bump `lastAnalyzedCommit` to current `HEAD` SHA.
- If stack/role drift was confirmed by the user: update `manifest.projectType`, `manifest.stack`, and `manifest.roles` to reflect the new state.
- Leave `initializedAt` unchanged.
- Leave `specCounter` unchanged.

Write the manifest back using the same JSON shape defined in `reference/manifest.md`.

---

## Step 8 — Report

Output a concise summary covering three areas:

### Refreshed
List each file that was updated and a one-line description of what changed:
```
docs/architecture/overview.md — updated stack (added drizzle-orm), pruned stale data-flow entry
docs/conventions.md — updated Formatting section (biome replaced prettier)
.claude/agents/d-backend.md — generated (new role from drift)
```

### Preserved
List files that were explicitly kept as-is, with reason:
```
docs/specs/0001-auth-flow/ — specs are never touched by refresh
.claude/agents/d-pm.md — hand-edit detected, user chose to keep current version
```

### Drift
If drift was detected, summarize it and the outcome:
```
Stack drift: frontend → fullstack. User confirmed. d-backend.md generated.
```
or:
```
No drift detected.
```

---

## Hard Stops

- **Never delete `docs/specs/`** or any file under it.
- **Never overwrite a hand-edited agent or command file** without explicit user confirmation.
- **Never re-run first-time generation** after a refresh. Refresh updates; it does not rebuild.
- **Stop after the report.** Do not trigger `/d:task`, spec creation, or any other pipeline step.
