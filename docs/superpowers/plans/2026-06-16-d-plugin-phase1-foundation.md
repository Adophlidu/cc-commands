# d Plugin — Phase 1: Foundation + `/d:init` Existing-Project Path — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `d` Claude Code plugin skeleton and a working `/d:init` that, on an existing project, analyzes the codebase into `docs/architecture/` + `docs/conventions.md`, detects which roles apply, generates project-tailored subagents, runs a calibration checkpoint and a green-baseline self-test, and writes `manifest.json`.

**Architecture:** A distributable plugin whose only command is `/d:init`. `/d:init` is a prompt the main agent executes; its logic lives in `commands/init.md` plus `reference/*.md` guides it reads. The command-naming approach (`/d:init`) is validated by a spike before anything else is built. Generation of `/d:task` and `/d:fix` command files is deferred to Plans 2–3 (which author those templates).

**Tech Stack:** Claude Code plugin (markdown commands + agents + reference docs), JSON manifests, `context7` MCP for best-practice lookups, `git` for version control. No application runtime — verification is dogfooding `/d:init` against fixture repos.

**Adaptation note (read first):** This plugin is prompt engineering, not application code. There are no unit tests for markdown prompts. "Tests" here are: (a) JSON/structure validation for config, and (b) a **fixture dogfood run** — install the plugin, run `/d:init` on a known small repo, and assert the produced artifacts match an expected checklist. Where a task authors a prompt/reference file, its "verify" step checks the file contains the required sections; the end-to-end dogfood (Task 12) is the real integration test.

---

## File Structure

Plugin repo root: `/Users/dudu/cc-commands`

- Create: `.claude-plugin/plugin.json` — plugin manifest (name `d`, version, description)
- Create: `.claude-plugin/marketplace.json` — local dev marketplace entry so the plugin can be installed
- Create: `commands/init.md` — the `/d:init` orchestrator prompt (detection + pipeline) — **path may become `commands/d/init.md` pending Task 1 spike**
- Create: `reference/analyze-codebase.md` — how to explore a codebase and write `docs/architecture/`
- Create: `reference/conventions-extraction.md` — how to build `docs/conventions.md` (explicit configs + inference + grep-verify + context7)
- Create: `reference/command-extraction.md` — extract + actually run lint/format/typecheck/test/build to verify they work
- Create: `reference/detect-roles.md` — project-type classification + role tailoring rules
- Create: `reference/ui-setup.md` — UI-handling flow (external tool MCP check vs AI-decides → design.md)
- Create: `reference/manifest.md` — manifest.json schema + write rules
- Create: `reference/agent-templates/d-pm.md` — d-pm skeleton with placeholders
- Create: `reference/agent-templates/d-frontend.md`
- Create: `reference/agent-templates/d-backend.md`
- Create: `reference/agent-templates/d-tester.md`
- Create: `reference/agent-templates/d-ui.md`
- Create: `reference/agent-templates/d-reviewer.md`
- Create: `tests/fixtures/sample-fullstack/` — a tiny but real project to dogfood against
- Create: `tests/CHECKLIST.md` — the expected-artifacts checklist used in Task 12

Placeholder convention across templates: `{{LIKE_THIS}}` marks a slot `/d:init` fills with project-specific extracted content.

---

## Task 1: Command-naming spike (validate `/d:init`)

Risk #1 in the spec: confirm a plugin command actually renders as `/d:init`. Settle this before building anything else.

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `commands/init.md` (temporary minimal body)

- [ ] **Step 1: Write minimal plugin.json**

`.claude-plugin/plugin.json`:
```json
{
  "name": "d",
  "description": "AI project workflow engine: init, iterate (task), and fix bugs with project-tailored subagents",
  "version": "0.1.0",
  "author": { "name": "dudu", "email": "frezzaarbry825@gmail.com" },
  "license": "MIT",
  "keywords": ["workflow", "subagents", "scaffolding", "project-init"]
}
```

- [ ] **Step 2: Write minimal marketplace.json**

`.claude-plugin/marketplace.json`:
```json
{
  "name": "d-dev",
  "description": "Development marketplace for the d workflow plugin",
  "owner": { "name": "dudu", "email": "frezzaarbry825@gmail.com" },
  "plugins": [
    { "name": "d", "description": "AI project workflow engine", "version": "0.1.0", "source": "./" }
  ]
}
```

- [ ] **Step 3: Write a stub command**

`commands/init.md`:
```markdown
---
description: Initialize d workflow for this project (spike build)
argument-hint: (none)
---

SPIKE: print exactly `D_INIT_REACHED` and stop. Do nothing else.
```

- [ ] **Step 4: Validate JSON**

Run: `python3 -c "import json; [json.load(open(f)) for f in ['.claude-plugin/plugin.json','.claude-plugin/marketplace.json']]" && echo OK`
Expected: `OK`

- [ ] **Step 5: Install the local plugin and check the command name**

Run: `claude plugin marketplace add /Users/dudu/cc-commands && claude plugin install d@d-dev`
Then in a Claude session run `/help` (or list commands) and confirm the command appears as `/d:init`.
Expected: command listed as `/d:init`.

**If it appears as `/init` or `/d:d` or anything else:** try moving the command to `commands/d/init.md` (subdirectory namespacing) and reinstall; re-check. Record the working layout in a comment at the top of `commands/init.md`. **All later tasks use whatever path made `/d:init` work.**

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin commands
git commit -m "feat(d): plugin skeleton + validate /d:init command naming"
```

---

## Task 2: Manifest schema reference

Defines the single source of project state that `/d:init` writes and later commands read.

**Files:**
- Create: `reference/manifest.md`

- [ ] **Step 1: Write the manifest schema doc**

`reference/manifest.md` must contain: (1) the exact JSON shape below, (2) field semantics, (3) the rule that the manifest is written at `.claude/d/manifest.json` in the target project, (4) the rule that re-running `/d:init` reads it to detect an already-initialized project.

```jsonc
{
  "version": 1,
  "initializedAt": "<ISO8601>",
  "lastAnalyzedCommit": "<git sha or null>",
  "projectType": "fullstack | frontend | backend | cli | library",
  "stack": { "frontend": "<e.g. react+tanstack-router>", "backend": "<e.g. hono>", "database": "<e.g. postgres>", "orm": "<e.g. drizzle>", "test": "<e.g. vitest>", "pm": "<npm|pnpm|bun>" },
  "roles": ["d-pm", "d-frontend", "d-backend", "d-tester", "d-ui", "d-reviewer"],
  "qualityGate": { "lint": "<cmd or null>", "format": "<cmd or null>", "typecheck": "<cmd or null>", "extra": [] },
  "testGate": { "test": "<cmd or null>", "build": "<cmd or null>" },
  "uiBaseline": { "mode": "design | regression | none", "designSource": "<figma url | path | docs/design.md | null>", "tool": "playwright | backstopjs | null" },
  "specCounter": 0
}
```

- [ ] **Step 2: Verify required sections present**

Run: `grep -E "projectType|qualityGate|uiBaseline|specCounter|\.claude/d/manifest\.json" reference/manifest.md | wc -l`
Expected: a count ≥ 5.

- [ ] **Step 3: Commit**

```bash
git add reference/manifest.md
git commit -m "docs(d): manifest schema reference"
```

---

## Task 3: Codebase-analysis reference

Tells `/d:init` how to produce `docs/architecture/`.

**Files:**
- Create: `reference/analyze-codebase.md`

- [ ] **Step 1: Write the analysis guide**

`reference/analyze-codebase.md` must specify:
- **Adaptive depth**: small repo → single pass to one `overview.md`; large repo → dispatch parallel `Explore` agents per top-level area, then write per-module files.
- **What `overview.md` must capture**: tech stack, layering, data flow, entry points, build/run commands, directory map.
- **Per-module files** (`docs/architecture/<module>.md`) only when a module is non-trivial: responsibility, key files, public interface, dependencies.
- **Fit rule**: every statement must be grounded in real files — cite concrete paths (`src/...`), never generic descriptions.
- **Output location**: `docs/architecture/` in the target project.

- [ ] **Step 2: Verify**

Run: `grep -E "overview\.md|Explore|data flow|docs/architecture" reference/analyze-codebase.md | wc -l`
Expected: count ≥ 4.

- [ ] **Step 3: Commit**

```bash
git add reference/analyze-codebase.md
git commit -m "docs(d): codebase analysis reference"
```

---

## Task 4: Conventions-extraction reference

Tells `/d:init` how to produce `docs/conventions.md` — the code source of truth.

**Files:**
- Create: `reference/conventions-extraction.md`

- [ ] **Step 1: Write the conventions guide**

Must specify the merge of three sources:
1. **Explicit**: scan lint/formatter configs (eslint/biome/prettier), `tsconfig.json` strictness, `CONTRIBUTING`, existing `CLAUDE.md`, editorconfig.
2. **Inferred**: AI reads code for naming, structure, error-handling, module patterns, common pitfalls.
3. **Best practice (context7)**: pull the chosen framework's current official style/best-practice guide and fold in what's missing.

Plus these hard rules:
- **Grep-verify before codifying**: any inferred convention must be confirmed to dominate via a `Grep` over the repo before it's written (avoid imposing non-existent conventions).
- **If lint/format/typecheck config is missing, author it** (so the quality gate has something to run) using the framework's recommended preset.
- **Lean**: `docs/conventions.md` is a tight reference, not a changelog.
- **Output**: `docs/conventions.md` in the target project.

- [ ] **Step 2: Verify**

Run: `grep -E "context7|Grep|grep-verify|eslint|biome|tsconfig|docs/conventions" reference/conventions-extraction.md | wc -l`
Expected: count ≥ 4.

- [ ] **Step 3: Commit**

```bash
git add reference/conventions-extraction.md
git commit -m "docs(d): conventions extraction reference"
```

---

## Task 5: Command-extraction & green-baseline reference

The fit-guarantee mechanism: extract the project's real commands and actually run them.

**Files:**
- Create: `reference/command-extraction.md`

- [ ] **Step 1: Write the guide**

Must specify:
- **Extract** lint/format/typecheck/test/build/dev from `package.json` scripts (and equivalents for non-JS stacks: Makefile, pyproject, cargo, go).
- **Actually run each once** (`<pm> run lint`, etc.) to confirm it exists and exits cleanly; record the working command strings into `manifest.qualityGate` / `manifest.testGate`.
- **A command that does not exist or errors on clean HEAD is a broken gate** → either fix the config (Task 4 authoring) or set the field to `null` and note the gap in the calibration summary.
- This data feeds the green-baseline self-test in `commands/init.md` (Task 11).

- [ ] **Step 2: Verify**

Run: `grep -E "package.json|qualityGate|testGate|green|baseline|run" reference/command-extraction.md | wc -l`
Expected: count ≥ 4.

- [ ] **Step 3: Commit**

```bash
git add reference/command-extraction.md
git commit -m "docs(d): command extraction + green baseline reference"
```

---

## Task 6: Role-detection reference

**Files:**
- Create: `reference/detect-roles.md`

- [ ] **Step 1: Write the role-detection rules**

Must specify:
- **Always generated** (every project): `d-pm`, `d-tester`, `d-reviewer`.
- **Conditional**: `d-frontend` + `d-ui` if a frontend/UI layer exists; `d-backend` if a server/API/DB layer exists.
- **Classification → projectType**: `fullstack` (both), `frontend` (UI only), `backend` (server only, has API/DB), `cli` (command-line entry, no UI/server), `library` (published package, no app entry).
- Detection signals table (e.g., presence of `src/components` / a router → frontend; `hono`/`express`/route handlers / a db schema → backend; a `bin` field / CLI entry → cli; a `main`/`exports` with no app entry → library).
- Output: the chosen `projectType` and `roles[]` go into the manifest.

- [ ] **Step 2: Verify**

Run: `grep -E "d-pm|d-reviewer|fullstack|frontend|backend|cli|library" reference/detect-roles.md | wc -l`
Expected: count ≥ 6.

- [ ] **Step 3: Commit**

```bash
git add reference/detect-roles.md
git commit -m "docs(d): role detection reference"
```

---

## Task 7: UI-setup reference

**Files:**
- Create: `reference/ui-setup.md`

- [ ] **Step 1: Write the UI-setup flow**

Must specify (only runs when `roles` includes `d-ui`; otherwise skipped):
- Main agent asks the user "how is UI handled?" (interaction is main-agent-driven — subagents can't ask the user).
- **External tool (Figma/Stitch/other)**: detect whether the matching MCP is available; if not, instruct the user to bind it. Set `uiBaseline.mode="design"`, `designSource=<figma|stitch>`. **External tool is the sole source of truth — do not generate `docs/design.md`.**
- **AI decides**: main agent asks UI preferences (style/tone/color/density/reference products), then **delegates to d-ui** to write `docs/design.md` (aesthetic, typography, color, layout, spacing, component rules), combining preferences + requirements + best practices. Set `designSource="docs/design.md"`.
- d-ui's visual gate later compares implementation vs `designSource`.

- [ ] **Step 2: Verify**

Run: `grep -E "Figma|Stitch|MCP|design.md|designSource|sole source" reference/ui-setup.md | wc -l`
Expected: count ≥ 5.

- [ ] **Step 3: Commit**

```bash
git add reference/ui-setup.md
git commit -m "docs(d): UI setup reference"
```

---

## Task 8: Agent templates — d-pm, d-tester, d-reviewer (always-generated trio)

These skeletons get copied into the project's `.claude/agents/` with `{{SLOTS}}` filled by `/d:init`.

**Files:**
- Create: `reference/agent-templates/d-pm.md`
- Create: `reference/agent-templates/d-tester.md`
- Create: `reference/agent-templates/d-reviewer.md`

- [ ] **Step 1: Write d-pm template**

`reference/agent-templates/d-pm.md` — frontmatter + body:
```markdown
---
name: d-pm
description: Splits requirements into specs with API contracts; reviews tester/ui coverage; owns reflow into architecture/conventions docs
tools: Read, Grep, Glob, Write
---

You are the PM for {{PROJECT_NAME}} ({{PROJECT_TYPE}}, stack: {{STACK_SUMMARY}}).

Always read `docs/architecture/overview.md` and `docs/conventions.md` before acting.

Responsibilities:
1. Decompose a requirement into sub-tasks; write a spec to `docs/specs/{{NNNN}}-<slug>/spec.md` with: task breakdown, acceptance criteria, owning agent per sub-task, and an explicit API contract (endpoints / inputs / outputs / errors) when backend+frontend interact.
2. Coverage gate: given tester/ui generated cases, judge whether they cover the spec; approve or send back.
3. Reflow: integrate durable learnings into `docs/architecture` and `docs/conventions.md` — edit in place, supersede stale entries, keep it lean.

You only write under `docs/`. You never write application code.
```

- [ ] **Step 2: Write d-tester template**

`reference/agent-templates/d-tester.md`:
```markdown
---
name: d-tester
description: Authors real test cases as the test gate; runs them as pass/fail; does root-cause analysis for fixes; fixes its own broken test scripts
tools: Read, Grep, Glob, Write, Edit, Bash
---

You are the tester for {{PROJECT_NAME}}. Test framework: {{TEST_FRAMEWORK}}. Test command: `{{TEST_CMD}}`.

Always read `docs/conventions.md` and the relevant `docs/specs/NNNN-*/spec.md`.

Responsibilities:
1. Turn each spec acceptance criterion into a real test in {{TEST_FRAMEWORK}} (follow existing tests, e.g. {{TEST_EXEMPLAR}}).
2. The test gate's verdict is `{{TEST_CMD}}`'s exit status — never a subjective judgment.
3. If a test itself is wrong, fix the test (not the feature's job).
4. For `/d:fix`: reproduce, find the root cause (no fix without root cause), report it.
```

- [ ] **Step 3: Write d-reviewer template**

`reference/agent-templates/d-reviewer.md`:
```markdown
---
name: d-reviewer
description: Mechanical quality gate (lint + format + typecheck + optional arch/complexity lint); pass/fail by script result; supplements with convention-adherence review
tools: Read, Grep, Glob, Edit, Bash
---

You are the quality gate for {{PROJECT_NAME}}.
Quality commands: lint=`{{LINT_CMD}}`, format-check=`{{FORMAT_CMD}}`, typecheck=`{{TYPECHECK_CMD}}`{{EXTRA_GATES}}.

Responsibilities:
1. Run every quality command; the verdict is their combined exit status.
2. If a gate's config is broken, fix the config (so the gate is real).
3. Beyond lint: review naming / layering / structure against `docs/conventions.md` and flag violations lint can't catch.
You never weaken a gate to make it pass.
```

- [ ] **Step 4: Verify all three parse as having frontmatter + slots**

Run: `for f in d-pm d-tester d-reviewer; do head -1 reference/agent-templates/$f.md; grep -c "{{" reference/agent-templates/$f.md; done`
Expected: each file's first line is `---` and each has ≥ 1 `{{` slot.

- [ ] **Step 5: Commit**

```bash
git add reference/agent-templates/d-pm.md reference/agent-templates/d-tester.md reference/agent-templates/d-reviewer.md
git commit -m "feat(d): always-generated agent templates (pm, tester, reviewer)"
```

---

## Task 9: Agent templates — d-frontend, d-backend, d-ui (conditional)

**Files:**
- Create: `reference/agent-templates/d-frontend.md`
- Create: `reference/agent-templates/d-backend.md`
- Create: `reference/agent-templates/d-ui.md`

- [ ] **Step 1: Write d-frontend template**

```markdown
---
name: d-frontend
description: Implements frontend per spec + API contract, obeying inlined project conventions
tools: Read, Grep, Glob, Write, Edit, Bash
---

You implement the frontend for {{PROJECT_NAME}}. Stack: {{FRONTEND_STACK}}.

Hard rules (inlined from this project's conventions):
{{CONVENTION_RULES}}

Follow real exemplars: components like {{COMPONENT_EXEMPLAR}}; state/data like {{DATA_EXEMPLAR}}.
Always read the active `docs/specs/NNNN-*/spec.md` and honor its API contract exactly.
Full conventions: `docs/conventions.md`.
```

- [ ] **Step 2: Write d-backend template**

```markdown
---
name: d-backend
description: Implements backend / API / DB per spec + API contract, obeying inlined project conventions
tools: Read, Grep, Glob, Write, Edit, Bash
---

You implement the backend for {{PROJECT_NAME}}. Stack: {{BACKEND_STACK}} (db: {{DATABASE}}, orm: {{ORM}}).

Hard rules (inlined from this project's conventions):
{{CONVENTION_RULES}}

Follow real exemplars: handlers like {{HANDLER_EXEMPLAR}}; schema/migrations like {{SCHEMA_EXEMPLAR}}.
Implement exactly the API contract in the active spec. Full conventions: `docs/conventions.md`.
```

- [ ] **Step 3: Write d-ui template**

```markdown
---
name: d-ui
description: Owns the visual gate; authors docs/design.md when AI decides UI; runs visual-regression scripts against designSource
tools: Read, Grep, Glob, Write, Edit, Bash
---

You own UI quality for {{PROJECT_NAME}}. Design source of truth: {{DESIGN_SOURCE}}. Visual tool: {{UI_TOOL}}.

Responsibilities:
1. At init (AI-decides UI only): write `docs/design.md` from preferences + requirements + best practices.
2. Per task: generate/maintain visual-regression scenarios comparing implementation vs {{DESIGN_SOURCE}}.
3. The visual gate's verdict is the diff script's result. Fix your own broken scripts.
Reflow better UI approaches back into `docs/design.md` (edit in place, keep lean) — unless the source of truth is an external tool.
```

- [ ] **Step 4: Verify**

Run: `for f in d-frontend d-backend d-ui; do head -1 reference/agent-templates/$f.md; grep -c "{{" reference/agent-templates/$f.md; done`
Expected: each first line `---`, each ≥ 1 `{{` slot.

- [ ] **Step 5: Commit**

```bash
git add reference/agent-templates/d-frontend.md reference/agent-templates/d-backend.md reference/agent-templates/d-ui.md
git commit -m "feat(d): conditional agent templates (frontend, backend, ui)"
```

---

## Task 10: The `/d:init` orchestrator (existing-project path)

Ties the references together into the command prompt. New-project + incremental-refresh paths are stubbed here and built in Plan 4.

**Files:**
- Modify: `commands/init.md` (replace the spike body) — path per Task 1 result

- [ ] **Step 1: Write the full command prompt**

Replace `commands/init.md` body with a prompt that instructs the main agent to:

1. **Detect state**: if `.claude/d/manifest.json` exists → say "already initialized; incremental refresh lands in Plan 4" and stop (placeholder for now). Else continue.
2. **Detect new vs existing**: if the directory is empty or only `.git`/`README`/`LICENSE` → say "new-project scaffolding lands in Plan 4" and stop (placeholder). Else run the existing-project path:
3. **Analyze** per `reference/analyze-codebase.md` → write `docs/architecture/`.
4. **Conventions** per `reference/conventions-extraction.md` → write `docs/conventions.md` (author missing lint/format/tsconfig configs).
5. **Extract & verify commands** per `reference/command-extraction.md` → fill `qualityGate`/`testGate` working strings.
6. **Detect roles** per `reference/detect-roles.md` → `projectType` + `roles[]`.
7. **UI setup** per `reference/ui-setup.md` (only if `d-ui` in roles).
8. **⏸ Calibration checkpoint**: present extracted architecture summary, conventions highlights, role roster, and the resolved gate commands; let the user correct before generating. Use AskUserQuestion / wait for confirmation.
9. **Generate agents**: for each role, copy `reference/agent-templates/<role>.md` into `.claude/agents/<role>.md`, filling every `{{SLOT}}` from extracted data and inlining the project's convention rules + real exemplar paths.
10. **Green-baseline self-test**: run the resolved `qualityGate` + `testGate` commands against current HEAD. If a gate fails on clean code, fix the gate config and re-run until green (or record the gap if no config can exist).
11. **Write manifest** to `.claude/d/manifest.json` per `reference/manifest.md`.
12. **Summary**: print what was created, the gate commands, the green-baseline result, and that `/d:task` and `/d:fix` will be added in later plans.

The prompt must explicitly reference each `reference/*.md` by path so the agent reads them.

- [ ] **Step 2: Verify the command references every guide**

Run: `grep -oE "reference/[a-z-]+(/[a-z-]+)?\.md" commands/init.md | sort -u`
Expected: lists `analyze-codebase`, `conventions-extraction`, `command-extraction`, `detect-roles`, `ui-setup`, `manifest`, and `agent-templates/`.

- [ ] **Step 3: Verify the calibration checkpoint and green-baseline are present**

Run: `grep -E "checkpoint|calibration|green|baseline|manifest.json" commands/init.md | wc -l`
Expected: count ≥ 4.

- [ ] **Step 4: Commit**

```bash
git add commands/init.md
git commit -m "feat(d): /d:init existing-project orchestrator"
```

---

## Task 11: Build the dogfood fixture + expected-artifacts checklist

A tiny real project to run `/d:init` against, plus the pass criteria.

**Files:**
- Create: `tests/fixtures/sample-fullstack/package.json`
- Create: `tests/fixtures/sample-fullstack/src/server/index.ts`
- Create: `tests/fixtures/sample-fullstack/src/web/App.tsx`
- Create: `tests/fixtures/sample-fullstack/tsconfig.json`
- Create: `tests/CHECKLIST.md`

- [ ] **Step 1: Write a minimal fullstack fixture**

`tests/fixtures/sample-fullstack/package.json`:
```json
{
  "name": "sample-fullstack",
  "private": true,
  "scripts": {
    "lint": "echo 'lint ok'",
    "format": "echo 'format ok'",
    "typecheck": "echo 'typecheck ok'",
    "test": "echo 'test ok'",
    "build": "echo 'build ok'"
  }
}
```

`tests/fixtures/sample-fullstack/src/server/index.ts`:
```ts
// Minimal Hono-style API so role detection sees a backend.
export const routes = { "GET /health": () => ({ ok: true }) };
```

`tests/fixtures/sample-fullstack/src/web/App.tsx`:
```tsx
// Minimal React component so role detection sees a frontend/UI.
export function App() { return <div>hello</div>; }
```

`tests/fixtures/sample-fullstack/tsconfig.json`:
```json
{ "compilerOptions": { "strict": true, "jsx": "react-jsx" } }
```

- [ ] **Step 2: Write the expected-artifacts checklist**

`tests/CHECKLIST.md` lists what a successful `/d:init` run on `sample-fullstack` must produce:
```markdown
# /d:init dogfood checklist (sample-fullstack)

- [ ] docs/architecture/overview.md exists and names the real stack (React + Hono) with cited paths (src/web, src/server)
- [ ] docs/conventions.md exists, merges tsconfig strict + inferred rules
- [ ] projectType resolved to "fullstack"
- [ ] .claude/agents/ contains d-pm, d-tester, d-reviewer, d-frontend, d-backend, d-ui (all six)
- [ ] each agent file has NO remaining {{SLOTS}}
- [ ] .claude/d/manifest.json is valid JSON with qualityGate.lint = "<pm> run lint" (or resolved string), testGate.test set
- [ ] a calibration checkpoint was shown before generation
- [ ] green-baseline self-test ran the gate commands and reported pass
```

- [ ] **Step 3: Verify fixture is detectable**

Run: `ls tests/fixtures/sample-fullstack/src/web tests/fixtures/sample-fullstack/src/server && python3 -c "import json;json.load(open('tests/fixtures/sample-fullstack/package.json'));print('OK')"`
Expected: both dirs listed, `OK`.

- [ ] **Step 4: Commit**

```bash
git add tests/
git commit -m "test(d): dogfood fixture + expected-artifacts checklist"
```

---

## Task 12: End-to-end dogfood run (the integration test)

**Files:**
- Uses: installed `d` plugin + `tests/fixtures/sample-fullstack`

- [ ] **Step 1: Copy the fixture to a scratch dir (so generated files don't dirty the repo)**

Run: `rm -rf /tmp/d-dogfood && cp -r tests/fixtures/sample-fullstack /tmp/d-dogfood && cd /tmp/d-dogfood && git init -q && git add -A && git commit -qm init && echo READY`
Expected: `READY`

- [ ] **Step 2: Reinstall the plugin with the final code**

Run: `claude plugin marketplace update d-dev || claude plugin install d@d-dev`
Expected: install/update succeeds.

- [ ] **Step 3: Run `/d:init` against the scratch project**

In a Claude session with working dir `/tmp/d-dogfood`, run `/d:init`. Answer the UI-setup question with "let AI decide" and confirm the calibration checkpoint.

- [ ] **Step 4: Verify every checklist item**

Run:
```bash
cd /tmp/d-dogfood && \
ls docs/architecture/overview.md docs/conventions.md .claude/d/manifest.json && \
ls .claude/agents/d-pm.md .claude/agents/d-tester.md .claude/agents/d-reviewer.md .claude/agents/d-frontend.md .claude/agents/d-backend.md .claude/agents/d-ui.md && \
! grep -rl "{{" .claude/agents/ && \
python3 -c "import json;m=json.load(open('.claude/d/manifest.json'));assert m['projectType']=='fullstack';assert m['qualityGate']['lint'];assert m['testGate']['test'];print('MANIFEST OK')"
```
Expected: all paths exist, no `{{` slots remain, `MANIFEST OK`. Walk `tests/CHECKLIST.md` and tick each box.

- [ ] **Step 5: If any item fails, fix the relevant reference/template/command and re-run from Step 2.**

- [ ] **Step 6: Commit the validated state (plugin code only — scratch dir is throwaway)**

```bash
cd /Users/dudu/cc-commands && git commit --allow-empty -m "test(d): phase 1 dogfood passes on sample-fullstack fixture"
```

---

## Self-Review (completed)

**Spec coverage (Phase 1 scope = spec §3.2 existing-project path + §3.4 fit + §6 UI-setup + §8 manifest):**
- §3.2 analyze → architecture: Task 3 ✓ · conventions: Task 4 ✓ · command extraction: Task 5 ✓ · role detection: Task 6 ✓ · UI setup: Task 7 ✓ · calibration checkpoint: Task 10 step 8 ✓ · agent generation: Tasks 8–9 + Task 10 step 9 ✓ · green baseline: Task 10 step 10 ✓ · manifest: Task 2 + Task 10 step 11 ✓
- §3.4 fit guarantee (thin templates, real commands run, real exemplars, grep-verify, checkpoint, green baseline): Tasks 4,5,8,9,10 ✓
- Command naming risk (§ risk #1): Task 1 spike ✓
- **Deferred to later plans (intentionally out of Phase 1 scope):** `/d:task` orchestration + 3-gate loop + reflow (Plan 2, spec §5/§7), `/d:fix` (Plan 3, spec §6), new-project better-t-stack path + incremental refresh (Plan 4, spec §3.1/§3.3). `commands/init.md` stubs these with explicit "lands in Plan 4" messages.

**Placeholder scan:** `{{SLOT}}` markers are intentional template slots, not plan placeholders; Task 12 step 4 asserts none survive into generated output. No "TBD/handle edge cases" steps remain.

**Type/name consistency:** manifest field names (`qualityGate`, `testGate`, `uiBaseline`, `projectType`, `roles`, `specCounter`) are identical across Task 2, the agent templates, Task 10, and Task 12 assertions. Agent names (`d-pm`, `d-frontend`, `d-backend`, `d-tester`, `d-ui`, `d-reviewer`) are consistent across detect-roles (Task 6), templates (Tasks 8–9), and the checklist (Task 11).

---

## Next plans (to be written after Phase 1 lands)

- **Plan 2 — `/d:task`:** author `reference/command-templates/task.template.md` + worker orchestration; `/d:init` generates `.claude/commands/d/task.md`. Covers spec §5 (spec checkpoint, parallel implement, 3-gate accept/reject, 3-round escalation) + §7 reflow.
- **Plan 3 — `/d:fix`:** `reference/command-templates/fix.template.md`; root-cause checkpoint, routed fix, regression + quality gate, reflow. Spec §6.
- **Plan 4 — new project + refresh:** `reference/better-t-stack.md`, the new-project scaffolding branch in `commands/init.md`, and the incremental-refresh mode (§3.1, §3.3) with lean-docs consolidation.
