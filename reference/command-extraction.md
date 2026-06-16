# command-extraction

Instructs `/d:init` how to discover, verify, and record the target project's lint, format, typecheck, test, and build commands into the manifest's `qualityGate` and `testGate` fields.

## Purpose

`qualityGate` and `testGate` in `.claude/d/manifest.json` must contain **working command strings**, not guesses. This process extracts them from the project's tooling config, runs each one against the current HEAD, and records only the commands that exit cleanly. These verified commands become the green-baseline self-test that every subsequent `d` agent runs before marking work complete.

---

## Step 1 — Detect the Package Manager

Check the target project root for lockfiles in this priority order:

| Lockfile present | Package manager |
|---|---|
| `bun.lockb` or `bun.lock` | `bun` |
| `pnpm-lock.yaml` | `pnpm` |
| `package-lock.json` or `yarn.lock` | `npm` (or `yarn` — prefer `npm run` unless yarn is explicitly invoked in scripts) |
| None | `npm` (default fallback) |

Record the detected value in `stack.pm`. All subsequent run commands in this step use `<pm> run <script>`.

If no `package.json` exists at all, skip to Step 3 (non-JS stacks).

---

## Step 2 — Extract from `package.json` Scripts

Read the `scripts` block of `package.json`. Map script names to manifest fields using the table below. Match on **name substrings** (e.g. a script named `lint:check` matches `lint`).

| Manifest field | Candidate script name patterns |
|---|---|
| `qualityGate.lint` | `lint`, `eslint`, `biome:lint`, `check` (when lint-only) |
| `qualityGate.format` | `format`, `fmt`, `prettier`, `biome:format` |
| `qualityGate.typecheck` | `typecheck`, `type-check`, `tsc`, `types` |
| `testGate.test` | `test`, `test:unit`, `test:ci`, `vitest`, `jest` |
| `testGate.build` | `build`, `build:prod`, `compile` |

**Ambiguity rule:** If multiple scripts match a field (e.g. `test` and `test:ci`), prefer the CI-specific variant. If still ambiguous, prefer the shorter name.

**Monorepo rule:** If the project is a monorepo (contains `packages/` or `apps/` directories or a `workspaces` key in `package.json`), attempt the root-level script first. If it delegates to workspaces (`--recursive`, `-r`, `--filter "*"`), accept it as-is.

---

## Step 3 — Extract from Non-JS Stacks

Run these checks when the project does **not** have a `package.json`, or in addition to Step 2 for mixed stacks.

### Python (`pyproject.toml` / `tox.ini` / `Makefile`)

```bash
# Check for ruff, flake8, mypy, pytest
grep -E "^\[tool\.(ruff|flake8|mypy|pytest)\]" pyproject.toml 2>/dev/null
grep -E "^(lint|format|typecheck|test|build):" Makefile 2>/dev/null
```

Candidate commands:

| Manifest field | Commands to try (in order) |
|---|---|
| `qualityGate.lint` | `ruff check .`, `flake8 .`, `make lint` |
| `qualityGate.format` | `ruff format --check .`, `black --check .`, `make format` |
| `qualityGate.typecheck` | `mypy .`, `pyright`, `make typecheck` |
| `testGate.test` | `pytest`, `python -m pytest`, `tox`, `make test` |
| `testGate.build` | `python -m build`, `make build` |

### Rust (`Cargo.toml`)

| Manifest field | Command |
|---|---|
| `qualityGate.lint` | `cargo clippy -- -D warnings` |
| `qualityGate.format` | `cargo fmt --check` |
| `qualityGate.typecheck` | `cargo check` |
| `testGate.test` | `cargo test` |
| `testGate.build` | `cargo build --release` |

### Go (`go.mod`)

| Manifest field | Command |
|---|---|
| `qualityGate.lint` | `golangci-lint run` (if installed), else `go vet ./...` |
| `qualityGate.format` | `gofmt -l .` (exit 0 = clean) |
| `qualityGate.typecheck` | `go build ./...` (type-checks without emitting binaries) |
| `testGate.test` | `go test ./...` |
| `testGate.build` | `go build ./...` |

### Makefile (any stack)

When a `Makefile` is present alongside any of the above, check whether it defines targets named `lint`, `format`, `typecheck`, `test`, or `build`. If found, prefer `make <target>` over bare tool invocations, as Makefiles often encode project-specific flags.

---

## Step 4 — Run Each Candidate Command

For every candidate identified in Steps 2–3, run it in the target project root and observe the exit code.

```bash
# Example for a pnpm project
pnpm run lint      # expect exit 0
pnpm run format    # expect exit 0
pnpm run typecheck # expect exit 0
pnpm run test      # expect exit 0
pnpm run build     # expect exit 0
```

**Rules:**

- Run against the **current HEAD** without any uncommitted changes. The goal is to confirm the clean-slate baseline passes, not to fix existing failures.
- A command that exits 0 → record the full command string in the manifest field.
- A command that exits non-zero or does not exist → treat as a **broken gate** (see Step 5).
- If a test run would be slow (e.g. `cargo test` on a large project), add a `--no-run` or `--list` flag only if the test framework supports it without affecting gate validity. Otherwise run it fully — a slow gate is better than a wrong one.
- For `qualityGate.format`: run the formatter in **check mode** (read-only), not in write mode, so it exits non-zero on unformatted files without modifying them. Common flags: `--check` (prettier, ruff), `--check` (black), `-l` (gofmt).

---

## Step 5 — Broken-Gate Handling

A gate is **broken** when the candidate command does not exist in `package.json` / the toolchain, or exists but exits non-zero on a clean HEAD.

### Resolution order

1. **Config is absent** — if the gate is broken because the linter/formatter/typechecker was never configured, cross-reference `conventions-extraction.md` Step 1 "Hard rule: author missing config". Author the minimal config there, then re-run the candidate command. If it passes after authoring, record it.

2. **Config exists but command fails** — inspect the error output. Common causes:
   - Missing `devDependencies` (run `<pm> install`, then retry).
   - Script references a non-existent file or path (fix the script or the path).
   - TypeScript errors in existing code (do **not** suppress; note them in the calibration summary — existing type errors must be fixed before `/d:init` can set a green baseline).

3. **Gate is genuinely absent** — if the project has no lint, format, typecheck, test, or build tooling and authoring config is out of scope, set the manifest field to `null`.

**Calibration summary rule:** Any field left `null` must be called out in the calibration summary shown to the user at the end of `/d:init`. State which gate is missing and why, so the team can add it later.

---

## Step 6 — Record into Manifest

Write the verified commands into `.claude/d/manifest.json`:

```jsonc
{
  "qualityGate": {
    "lint": "pnpm run lint",        // or null
    "format": "pnpm run format",    // or null
    "typecheck": "pnpm run typecheck", // or null
    "extra": []
  },
  "testGate": {
    "test": "pnpm run test",        // or null
    "build": "pnpm run build"       // or null
  }
}
```

Use the exact command string that was run and exited 0 — no paraphrasing, no flag omission.

If a command was discovered in a `Makefile` or non-JS toolchain, record the full invocation (e.g. `"cargo clippy -- -D warnings"`, `"make lint"`).

---

## Green-Baseline Self-Test

After writing the manifest, run all non-null gates in sequence as a final self-test:

```bash
# Run each non-null gate; fail fast on first non-zero exit
<qualityGate.lint>     || FAIL "lint gate broke on clean HEAD"
<qualityGate.format>   || FAIL "format gate broke on clean HEAD"
<qualityGate.typecheck>|| FAIL "typecheck gate broke on clean HEAD"
<testGate.test>        || FAIL "test gate broke on clean HEAD"
<testGate.build>       || FAIL "build gate broke on clean HEAD"
```

If any gate fails at this point, it was written incorrectly. Re-examine the command and fix the manifest entry before proceeding. Do not leave a failing command in `qualityGate` or `testGate` — a gate that is recorded but fails is worse than `null`, because it will block every future agent.

---

## Verification Checklist

Before finalizing the manifest, confirm:

- [ ] Lockfile was checked and `stack.pm` is set correctly.
- [ ] `package.json` scripts block was read (or noted as absent).
- [ ] Non-JS toolchains were checked when `package.json` is absent or the stack is mixed.
- [ ] Every non-null gate command was actually run and exited 0 on the current HEAD.
- [ ] Every null gate has a note in the calibration summary.
- [ ] The green-baseline self-test passed (all recorded gates exit 0 in sequence).
- [ ] No gate command is recorded in write/mutating mode (format must be `--check` or equivalent).
