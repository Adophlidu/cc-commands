# better-t-stack Scaffolding

**Applies to:** Projects where `/d:init` is run in an **empty directory** and the user's described product is a good fit for the [Better-T Stack](https://github.com/AmanVarshney01/create-better-t-stack) (TypeScript full-stack apps with a Hono/tRPC/Drizzle/Better-Auth core).

**Skipped entirely** when the target directory is non-empty (existing project) or the user explicitly requests a different scaffold tool.

---

## Purpose

When scaffolding a new project, `/d:init` must produce a runnable codebase **before** running the normal analysis pipeline (Steps 3–14). This reference specifies how to select flags, confirm with the user, run the scaffold, commit the result, and hand off cleanly to the rest of init.

---

## Step 1 — Confirm the directory is empty

Before doing anything else, verify that the current working directory contains no files (hidden or otherwise). If files exist, this reference does not apply — proceed directly to the existing-project analysis pipeline.

```bash
ls -A .   # must produce no output
```

---

## Step 2 — Infer flags from the user's product description

Read the user's project description and map it to the flag set below using the heuristic table. The AI must produce a complete flag set — the user should not have to name any flags themselves.

### Non-interactive command form

```bash
npx create-better-t-stack@latest . --yes <flags>
```

Use `.` (current directory) as the target. `--yes` skips all interactive prompts so the scaffold runs unattended.

> **Runtime verification required.** The exact flag values listed below are authoritative as of the time this doc was written, but `create-better-t-stack` evolves quickly. Before running the command, confirm the current flag set with:
>
> ```bash
> npx create-better-t-stack@latest --help
> ```
>
> If flag names or accepted values differ from what is listed here, use the values reported by `--help`, not the values in this doc.

### Flag taxonomy

| Flag | Accepted values |
|---|---|
| `--frontend <types...>` | `tanstack-router`, `react-router`, `next`, `nuxt`, `svelte`, `none` |
| `--backend <value>` | `hono`, `express`, `fastify`, `elysia`, `convex`, `self`, `none` |
| `--database <value>` | `none`, `sqlite`, `postgres`, `mysql`, `mongodb` |
| `--orm <value>` | `none`, `drizzle`, `prisma`, `mongoose` |
| `--api <value>` | `none`, `trpc`, `orpc` |
| `--auth <value>` | `better-auth`, `clerk`, `none` |
| `--package-manager <value>` | `npm`, `pnpm`, `bun` |
| `--install` / `--no-install` | Install dependencies after scaffold / skip |
| `--git` / `--no-git` | Init git repo inside scaffold / skip |

Additional flags exist (`--runtime`, `--payments`, `--db-setup`, `--examples`) — check `--help` for current details and defaults.

Default package manager: **`pnpm`** unless the user specifies otherwise or a lockfile in the parent environment implies a different choice.

### Requirement → flag mapping

Use this table to translate product descriptions into flag choices. When a description matches multiple rows, combine their flags.

| User's product description | Recommended flags |
|---|---|
| Needs user accounts / auth | `--auth better-auth` |
| Needs a relational DB + user accounts | `--database postgres --orm drizzle --auth better-auth` |
| Needs a lightweight local/embedded DB | `--database sqlite --orm drizzle` |
| Document store / MongoDB | `--database mongodb --orm mongoose` |
| API + web app (standard full-stack) | `--backend hono --api trpc --frontend tanstack-router` |
| API only, no web frontend | `--backend hono --api trpc --frontend none` |
| Simple static site / SPA, no server | `--backend none --database none --api none` |
| Realtime or serverless backend | `--backend convex` |
| Bring your own backend (self-hosted) | `--backend self` |
| Uses Clerk for auth instead of self-hosted | `--auth clerk` |
| Wants type-safe RPC with oRPC instead of tRPC | `--api orpc` |
| Needs a native (mobile) frontend | `--frontend native` (check `--help` for current value) |

When the description is ambiguous, prefer the safer/more conventional choice (e.g., `postgres` over `mysql`, `drizzle` over `prisma` for new projects, `pnpm` over `npm`).

---

## Step 3 — Present the constructed command for confirmation

Do **not** run the scaffold silently. Present the full command and a one-line rationale for each non-default choice, then ask for a single confirmation (or an edit):

```
I'll scaffold this project with:

  npx create-better-t-stack@latest . --yes \
    --frontend tanstack-router \
    --backend hono \
    --database postgres \
    --orm drizzle \
    --api trpc \
    --auth better-auth \
    --package-manager pnpm \
    --install --no-git

Rationale:
  --frontend tanstack-router  → file-based routing, type-safe navigation
  --backend hono              → lightweight, edge-compatible server
  --database postgres         → relational DB for user data and app records
  --orm drizzle               → type-safe SQL, minimal overhead
  --api trpc                  → end-to-end type safety between client and server
  --auth better-auth          → user accounts required per your description
  --package-manager pnpm      → default; fastest installs
  --no-git                    → /d:init will handle the initial commit

OK to run? (yes / edit)
```

Accept a free-text edit ("change database to sqlite", "use bun instead") and reconstruct the command before running. Require only **one round** of confirmation — do not loop.

Use `--no-git` so that the initial commit is controlled by Step 4 below (not by the scaffold tool).

---

## Step 4 — Run the scaffold

Once confirmed, run the command exactly as constructed. Stream output so the user can see progress. If the scaffold exits non-zero, report the error and stop — do not proceed to later steps.

```bash
npx create-better-t-stack@latest . --yes \
  <confirmed flags>
```

---

## Step 5 — Commit the scaffolded code

After a successful scaffold, create a clean initial commit so the existing-project analysis pipeline has a stable HEAD baseline to compare against.

```bash
git init          # only if the directory is not already a git repo
git add -A
git commit -m "chore: scaffold project with create-better-t-stack"
```

If `git init` was required, also set the default branch name before committing:

```bash
git init -b main
```

Do **not** push to a remote at this stage.

---

## Step 6 — Hand off to the normal /d:init pipeline

With the scaffold committed, proceed into the standard `/d:init` analysis pipeline starting at Step 3 (stack detection / role inference). The scaffolded codebase is now treated as an existing project. All subsequent steps — command extraction, conventions extraction, manifest authoring, quality gate verification, and calibration summary — apply normally.

---

## Quick-reference checklist

- [ ] Directory confirmed empty before scaffold.
- [ ] `--help` output checked to verify flag values against current CLI.
- [ ] Full command with rationale presented and user confirmed (one round).
- [ ] `--no-git` used so `/d:init` owns the initial commit.
- [ ] Scaffold exited 0 before proceeding.
- [ ] Initial commit created (`git init` if needed, then `git add -A && git commit`).
- [ ] Hand-off to Step 3 of the normal pipeline completed.
