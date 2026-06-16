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
npx create-better-t-stack@latest . <every prompt-bearing flag set explicitly>
```

Use `.` (current directory) as the target.

> **Do NOT use `--yes` together with stack flags.** On current CLI versions `--yes` is **mutually exclusive** with the core stack flags (`--frontend`, `--backend`, `--database`, `--orm`, `--api`, `--auth`, `--examples`, …) and the command errors out: *"Cannot combine --yes with core stack configuration flags."* To run unattended with a chosen stack, **omit `--yes` and specify every prompt-bearing flag explicitly** instead. Any prompt-bearing flag you leave out triggers an interactive prompt.

> **Runtime verification required (do this first).** `create-better-t-stack` evolves quickly. Before running, confirm the current flags AND validate your constructed command non-interactively with:
>
> ```bash
> npx create-better-t-stack@latest --help            # current flag names + accepted values
> npx create-better-t-stack@latest . <flags> --dry-run   # validates; exits 0 and prints a canonical reproducibleCommand
> ```
>
> Use the values reported by `--help` over this doc if they differ, and run the exact `reproducibleCommand` that `--dry-run` emits.

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
| `--runtime <value>` | e.g. `bun`, `node`, `workers` — **prompt-bearing**, set it explicitly |
| `--api <value>` already listed; also `--server-deploy <value>`, `--web-deploy <value>` | deploy targets (or `none`) — prompt-bearing |
| `--payments <value>` | e.g. `none`, `polar` — prompt-bearing |
| `--db-setup <value>` | managed-DB setup or `none` — prompt-bearing |
| `--examples <value>` | e.g. `todo`, `none` |
| `--addons <value>` | extra add-ons or `none` |
| `--directory-conflict <value>` | `merge` / `overwrite` / `error` (how to handle non-empty dir) |
| `--install` / `--no-install` | Install dependencies after scaffold / skip |
| `--git` / `--no-git` | Init git repo inside scaffold / skip |

To run **fully non-interactively**, every prompt-bearing flag above must be set (otherwise that prompt appears). The frontend `native` option is split into concrete values (`native-bare` / `native-uniwind` / `native-unistyles`) — there is no bare `native`; confirm exact names via `--help`. The authoritative, current list is always `--help`; treat this table as a starting point and let `--dry-run` confirm the full set.

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
| Needs a native (mobile) frontend | `--frontend native-uniwind` (or `native-bare` / `native-unistyles` — check `--help`) |

When the description is ambiguous, prefer the safer/more conventional choice (e.g., `postgres` over `mysql`, `drizzle` over `prisma` for new projects, `pnpm` over `npm`).

---

## Step 3 — Present the constructed command for confirmation

Do **not** run the scaffold silently. Present the full command and a one-line rationale for each non-default choice, then ask for a single confirmation (or an edit):

```
I'll scaffold this project with:

  npx create-better-t-stack@latest . \
    --frontend tanstack-router \
    --backend hono \
    --database postgres \
    --orm drizzle \
    --api trpc \
    --auth better-auth \
    --runtime node \
    --examples todo \
    --payments none \
    --db-setup none \
    --web-deploy none --server-deploy none \
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
npx create-better-t-stack@latest . \
  <confirmed flags — every prompt-bearing flag set, NO --yes>
```

Tip: run the same command with `--dry-run` first; it validates the flags and prints the canonical `reproducibleCommand`, which you can then run verbatim.

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
