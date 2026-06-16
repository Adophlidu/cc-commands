# `d` — AI Project Workflow Engine

A Claude Code plugin that turns a single command into a complete, project-tailored development workflow. Run `/d:init` in any project and `d` analyzes it (or scaffolds a new one), writes living architecture/convention docs, generates a team of specialized subagents bound to *your* codebase, and gives you two project-local commands — `/d:task` to ship a requirement and `/d:fix` to kill a bug — each guarded by **three script-based quality gates** and a **knowledge-reflow** step that keeps the docs fresh but lean.

> **The core idea:** the framework is generic, but every artifact it generates is *fit to your project* — produced by real analysis + a calibration checkpoint + a green-baseline self-test, not by stamping out templates.

---

## Why

Long-lived projects rot when every new requirement is built with different conventions, untested, and undocumented. `d` makes consistency **mechanical**, not a matter of remembering:

- **Conventions are enforced, not suggested** — lint/format/typecheck run as a real gate, alongside tests and visual regression.
- **Docs are a source of truth that grows but stays lean** — every task/fix reflows durable learnings back into them, editing in place.
- **Subagents are bound to your architecture** — the project's rules and real exemplar files are inlined into each agent.

---

## Install

```bash
claude plugin marketplace add /path/to/cc-commands
claude plugin install d@d-dev
```

Then, in any project:

```bash
/d:init            # set up the workflow (detects new / existing / re-run)
/d:task "<requirement>"   # iterate a feature
/d:fix  "<bug>"           # diagnose + fix a bug
```

---

## The three commands at a glance

```mermaid
flowchart LR
    init["/d:init<br/>(global)"] -->|generates| agents["6 subagents<br/>+ docs + manifest"]
    init -->|generates| task["/d:task<br/>(project-local)"]
    init -->|generates| fix["/d:fix<br/>(project-local)"]
    task -->|uses| agents
    fix -->|uses| agents
    task -->|reflow| docs[("docs/<br/>architecture · conventions · design")]
    fix -->|reflow| docs
    agents -.reads.-> docs
```

---

## `/d:init` — set up (or scaffold) the project

`/d:init` is the only global command. It detects three situations and routes accordingly.

```mermaid
flowchart TD
    start(["/d:init"]) --> q1{".claude/d/manifest.json<br/>exists?"}
    q1 -->|yes| refresh["**Incremental refresh**<br/>re-analyze (diff-scoped) ·<br/>update docs in place ·<br/>preserve specs + hand-edits<br/>(overwrite-with-ask) ·<br/>report drift"]
    refresh --> stop1(["stop"])

    q1 -->|no| q2{"directory empty?"}
    q2 -->|yes| newp["**New project**<br/>ask for the requirement →<br/>infer better-t-stack flags →<br/>⏸ confirm once → scaffold →<br/>commit baseline"]
    newp --> pipeline
    q2 -->|no| pipeline

    subgraph pipeline ["Existing-project pipeline"]
        direction TB
        a1["analyze → docs/architecture/"]
        a2["extract conventions → docs/conventions.md<br/>(+ author missing lint/format/tsconfig)"]
        a3["extract & RUN gate commands<br/>(lint · format · typecheck · test · build)"]
        a4["detect roles → projectType"]
        a5["UI setup (if d-ui): Figma / AI-design / regression"]
        a6["⏸ **calibration checkpoint** (human review)"]
        a7["generate tailored subagents → .claude/agents/"]
        a8["generate /d:task + /d:fix → .claude/commands/d/"]
        a9["🟢 green-baseline self-test (gates pass on HEAD)"]
        a10["write .claude/d/manifest.json"]
        a1 --> a2 --> a3 --> a4 --> a5 --> a6 --> a7 --> a8 --> a9 --> a10
    end
    pipeline --> done(["ready: /d:task · /d:fix"])
```

**Two things make the output fit your project, not generic:**

- ⏸ **Calibration checkpoint** — before generating anything, `d` shows you the extracted architecture, conventions, role roster, and the resolved gate commands so you can correct them.
- 🟢 **Green-baseline self-test** — after generating, it runs the quality + test gates against your current `HEAD`. If a gate fails on clean code, the gate config is wrong and gets fixed before finishing.

---

## The subagents

`/d:init` generates only the roles your project needs. Three are always present; three are conditional.

| Agent | Role | Generated when |
|---|---|---|
| `d-pm` | Splits requirements into specs + API contracts; coverage-gates tests; owns doc reflow | always |
| `d-tester` | Writes real test cases (the **test gate**); root-cause analysis for fixes | always |
| `d-reviewer` | Runs lint + format + typecheck (the **quality gate**); convention review | always |
| `d-frontend` | Implements the frontend | a UI layer exists |
| `d-backend` | Implements the backend / API / DB | a server layer exists |
| `d-ui` | Owns the **visual gate**; authors `docs/design.md` | a UI layer exists |

Each worker has the project's conventions and real exemplar file paths inlined into its prompt — so it imitates your real code, not a generic ideal.

---

## `/d:task` — iterate a requirement

The main agent acts as conductor (subagents can't dispatch subagents). One human checkpoint after the spec; then it runs automatically through the three gates with a bounded reject loop.

```mermaid
flowchart TD
    t0(["/d:task '...'"]) --> t1["d-pm: decompose →<br/>docs/specs/NNNN-slug/spec.md<br/>+ API contract"]
    t1 --> t2["⏸ **spec checkpoint** (you approve)"]
    t2 --> t3["d-tester + d-ui:<br/>generate acceptance scripts"]
    t3 --> t4{"d-pm: coverage<br/>sufficient?"}
    t4 -->|no| t3
    t4 -->|yes| t5["d-frontend / d-backend:<br/>implement (parallel where independent)"]
    t5 --> gates

    subgraph gates ["Three gates — verdict = script exit status"]
        direction LR
        g1["🔧 quality<br/>lint·format·typecheck"]
        g2["✅ test<br/>test cases"]
        g3["👁 visual<br/>screenshot diff"]
    end

    gates --> t6{"all pass?"}
    t6 -->|"fail (under 3 rounds)"| t7["reject → worker fixes →<br/>re-run failing gate"]
    t7 --> gates
    t6 -->|"fail × 3"| esc(["⏸ escalate to you"])
    t6 -->|yes| t8["reflow durable learnings → docs"]
    t8 --> t9(["report + spec marked done"])
```

---

## `/d:fix` — diagnose and fix a bug

Symmetric to `/d:task`, but **root-cause first**: no fix is written until the diagnosis is confirmed, and verification centers on a regression test.

```mermaid
flowchart TD
    f0(["/d:fix '...'"]) --> f1["d-tester: reproduce +<br/>find root cause<br/>(no fix without root cause)"]
    f1 --> f2["⏸ **diagnosis checkpoint** (you confirm)"]
    f2 --> f3["route fix to owner<br/>(d-frontend / d-backend)"]
    f3 --> f4["d-tester: regression test<br/>(fails pre-fix, passes post-fix)"]
    f4 --> fg

    subgraph fg ["Gates — verdict = script exit status"]
        direction LR
        fg1["✅ test + regression"]
        fg2["🔧 quality"]
    end

    fg --> f5{"all pass?"}
    f5 -->|"fail (under 3 rounds)"| f6["reject → fix → re-run"]
    f6 --> fg
    f5 -->|"fail × 3"| fesc(["⏸ escalate to you"])
    f5 -->|yes| f7["reflow (root cause is a prime candidate)"]
    f7 --> f8(["record → docs/specs/NNNN-fix-slug/ + report"])
```

---

## Knowledge reflow — docs that grow but stay lean

Every successful `/d:task` and `/d:fix` ends with a reflow step, so the docs never drift from reality and never bloat.

```mermaid
flowchart LR
    cand["candidate learnings<br/>(surfaced by agents)"] --> bar{"durability bar:<br/>① general?<br/>② not already documented?<br/>③ stable, not one-off?"}
    bar -->|fails any| drop["drop"]
    bar -->|passes all| route{"which doc?"}
    route -->|"architecture / pitfalls / conventions"| pm["d-pm edits<br/>docs/architecture · conventions"]
    route -->|"better UI approach"| ui["d-ui edits<br/>docs/design.md"]
    pm --> lean["edit in place ·<br/>supersede stale ·<br/>history → git, not the doc"]
    ui --> lean
    lean --> commit["auto-commit + surface in report"]
```

---

## What a managed project looks like

```
your-project/
├── docs/
│   ├── architecture/        # extracted, kept current by reflow
│   │   └── overview.md
│   ├── conventions.md       # code source of truth (enforced by the quality gate)
│   ├── design.md            # UI source of truth (when AI decides UI)
│   └── specs/
│       └── 0001-some-feature/spec.md
└── .claude/
    ├── agents/              # d-pm, d-tester, d-reviewer, d-frontend, d-backend, d-ui
    ├── commands/d/          # task.md, fix.md  (→ /d:task, /d:fix)
    └── d/manifest.json      # project type, stack, roles, gate commands, ui baseline
```

---

## Design principles

- **Fit beats templates** — generic engine, project-specific output via analysis + calibration + green-baseline.
- **Gates are mechanical** — quality/test/visual verdicts come from script exit status, never vibes.
- **One human stop per command** — spec (task) / diagnosis (fix) checkpoints; everything else is automatic, with a 3-round reject cap before escalation.
- **Self-contained, opportunistically smart** — works standalone; uses installed skills (e.g. `systematic-debugging`, `design-review`) when present.
- **Docs are living and lean** — reflow edits in place; history lives in git.

---

## Project status

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation + `/d:init` (existing project) | ✅ |
| 2 | `/d:task` iteration | ✅ |
| 3 | `/d:fix` bug-fix | ✅ |
| 4 | New project (better-t-stack) + incremental refresh | ✅ |

The full design spec and per-phase implementation plans live in [`docs/superpowers/`](docs/superpowers/).

New projects are scaffolded with [Better-T Stack](https://better-t-stack.dev/).
