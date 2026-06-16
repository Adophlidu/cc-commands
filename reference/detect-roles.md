# detect-roles — Project Classification & Role Selection

## Purpose

When `/d:init` runs its first-time analysis, it must (1) classify the project into a `projectType` and (2) decide which subagent role files to generate. This document is the authoritative reference for both steps.

---

## Always-Generated Roles

Regardless of project type, **always** generate these three roles:

| Role | Responsibility |
|---|---|
| `d-pm` | Requirement decomposition — breaks work into specs, tracks spec counter |
| `d-tester` | Test gate — runs and interprets the `testGate` commands |
| `d-reviewer` | Quality gate — runs `qualityGate` commands, enforces standards |

These are universal gates. Every project needs requirement tracking, a test gate, and a quality gate.

---

## Conditional Roles

| Role | Generate when… |
|---|---|
| `d-frontend` | A frontend/UI layer is detected (see signals table below) |
| `d-ui` | Same condition as `d-frontend` — both are generated together or neither is |
| `d-backend` | A server, API, or database layer is detected |

If neither frontend nor backend signals are found (e.g. `cli` or `library`), only the three universal roles are generated.

---

## projectType Enum

Choose **exactly one** value:

| `projectType` | Meaning |
|---|---|
| `fullstack` | Both a frontend/UI layer and a backend/API/DB layer are present |
| `frontend` | UI layer exists; no server or DB layer |
| `backend` | Server/API/DB layer exists; no UI layer |
| `cli` | Command-line entry point (`bin` field or CLI entrypoint); no UI or server |
| `library` | Published package (`main`/`exports` + publish config); no app entry, no UI, no server |

---

## Detection Signals Table

Scan the project root and source tree for the following evidence. Combine signals — a single signal is rarely conclusive; prefer the majority reading.

### Frontend / UI Signals

| Signal | Evidence |
|---|---|
| `src/components/` directory exists | UI component tree |
| `src/pages/`, `src/views/`, `src/routes/` directory exists | Page/view structure |
| `.jsx` or `.tsx` files present | React/JSX UI |
| UI router dependency | `react-router`, `tanstack-router`, `vue-router`, `@angular/router`, `svelte-kit`, `next.js` in `package.json` |
| Bundler / dev-server config | `vite.config.*`, `webpack.config.*`, `next.config.*`, `nuxt.config.*`, `astro.config.*` |
| CSS framework config | `tailwind.config.*`, `postcss.config.*`, `uno.config.*` |
| HTML entry point | `index.html` at root or inside `public/` or `src/` |
| UI framework dependency | `react`, `vue`, `svelte`, `solid-js`, `angular` in `package.json` |

If **any two or more** of these signals fire → frontend layer detected.

### Backend / API / DB Signals

| Signal | Evidence |
|---|---|
| Server framework dependency | `hono`, `express`, `fastify`, `koa`, `nestjs`, `elysia` in `package.json` |
| Route handler files | `src/routes/`, `src/api/`, `src/controllers/`, files named `*.router.*` or `*.handler.*` |
| DB schema / ORM config | `drizzle.config.*`, `prisma/schema.prisma`, `knexfile.*`, `typeorm` config, `sequelize` config |
| ORM / DB client dependency | `drizzle-orm`, `prisma`, `knex`, `typeorm`, `sequelize`, `mongoose` in `package.json` |
| DB migration directory | `migrations/`, `db/migrations/`, `prisma/migrations/` |
| Server entrypoint file | `src/server.*`, `src/index.*` that imports a server framework |
| Environment DB vars in `.env.example` | `DATABASE_URL`, `POSTGRES_*`, `MONGO_URI`, `REDIS_URL` |

If **any two or more** of these signals fire → backend layer detected.

### CLI Signals

| Signal | Evidence |
|---|---|
| `bin` field in `package.json` | Package exposes a CLI executable |
| `src/cli.*` or `src/main.*` entrypoint | CLI entry file |
| CLI framework dependency | `commander`, `yargs`, `oclif`, `meow`, `cac` in `package.json` |

If CLI signals fire and **no** frontend or backend signals fire → `cli`.

### Library Signals

| Signal | Evidence |
|---|---|
| `main` or `exports` field in `package.json` | Package entry points declared |
| `publishConfig` or `files` field in `package.json` | Publish configuration present |
| No app-level entrypoint | No `index.html`, no server import, no `bin` field |
| `src/index.*` that only exports, never starts a server or CLI | Pure library surface |

If library signals fire and no frontend, backend, or CLI signals fire → `library`.

---

## Classification Decision Tree

```
Does a frontend/UI layer exist?  ──Yes──┐
                                        ├── Does a backend layer also exist? ──Yes──> fullstack
Does a backend layer exist?      ──Yes──┘                                   ──No───> frontend
                                        ──No──> Does a backend layer exist alone? ──Yes──> backend
                                                Does a CLI entrypoint exist?        ──Yes──> cli
                                                Otherwise (library signals)                > library
```

In ambiguous cases (e.g. a monorepo with mixed packages), prefer `fullstack` over narrower types.

---

## Resulting `roles[]` Array by projectType

| `projectType` | `roles[]` |
|---|---|
| `fullstack` | `["d-pm", "d-frontend", "d-backend", "d-tester", "d-ui", "d-reviewer"]` |
| `frontend` | `["d-pm", "d-frontend", "d-tester", "d-ui", "d-reviewer"]` |
| `backend` | `["d-pm", "d-backend", "d-tester", "d-reviewer"]` |
| `cli` | `["d-pm", "d-tester", "d-reviewer"]` |
| `library` | `["d-pm", "d-tester", "d-reviewer"]` |

For `cli`, `library`, and `backend` projects: no `d-frontend` or `d-ui` is generated, so the UI-setup step in `/d:init` is **skipped entirely**. Set `uiBaseline.mode` to `"none"` for these types.

---

## Output

Write the resolved values into the manifest (`.claude/d/manifest.json`):

```jsonc
{
  "projectType": "<chosen type>",
  "roles": ["<role1>", "<role2>", ...]
}
```

See `reference/manifest.md` for the full manifest shape and field semantics.
