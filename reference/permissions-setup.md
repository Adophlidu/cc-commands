# Permissions Pre-Grant (opt-in)

**Purpose:** Let the user approve **once** at `/d:init` so subsequent file edits/adds — and the project's own gate/git commands — don't prompt on every action during `/d:task` and `/d:fix`.

This is **opt-in**. Always ask before writing any permission grant.

---

## How Claude Code permissions work (the relevant bits)

- Permissions live in `.claude/settings*.json` under `permissions`.
- `permissions.defaultMode: "acceptEdits"` auto-accepts **Edit / Write / NotebookEdit** and basic filesystem Bash (`mkdir`/`mv`/`cp`/`touch`/etc.) within the project. It still prompts for risky Bash (`git push`, `curl`, …).
- `permissions.allow: ["Bash(<cmd>)", …]` whitelists specific Bash commands. A space before `*` enforces a word boundary: `Bash(npm run test *)` matches `npm run test --watch` but not `npm run tester`. `:*` is equivalent to ` *`.
- **Precedence:** `.claude/settings.local.json` (personal, gitignored) > `.claude/settings.json` (committed/shared) > user settings. Deny/ask rules always beat allow.

**Important caveats to tell the user:**
- `defaultMode` takes effect on the **next session** (not mid-session) — which matches the restart `/d:init` already recommends. `allow` rules reload live.
- Writing `.claude/settings.local.json` is itself a protected-path write that **prompts once** — that is the "approve once" moment.
- `.git/` and `.claude/` stay protected regardless. We do **not** use `bypassPermissions`/`auto` (Claude Code blocks a repo from self-granting those).

---

## Step 1 — Ask the user (opt-in)

> "Want me to pre-grant edit permission for this project so you're not prompted on every file change? I'll set `acceptEdits` mode and whitelist this project's gate + git commands in `.claude/settings.local.json` (personal, gitignored). You can revert any time by deleting that block. Risky commands (push, network) still prompt. [yes / no]"

If **no**, skip this entire step.

## Step 2 — Build the permission block

Read the resolved gate commands from the manifest (`qualityGate.lint/format/typecheck`, `testGate.test/build`). For each non-null command `C`, add **two** allow entries: the exact `Bash(C)` and the wildcard `Bash(C *)` (to cover flags). Also add git commands the workflow uses.

Target shape:

```jsonc
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash(<lint cmd>)",       "Bash(<lint cmd> *)",
      "Bash(<format cmd>)",     "Bash(<format cmd> *)",
      "Bash(<typecheck cmd>)",  "Bash(<typecheck cmd> *)",
      "Bash(<test cmd>)",       "Bash(<test cmd> *)",
      "Bash(<build cmd>)",      "Bash(<build cmd> *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git status *)",
      "Bash(git diff *)"
    ]
  }
}
```

(Skip any gate whose command is `null`. Do not add `git push` — it should keep prompting.)

## Step 3 — Merge into `.claude/settings.local.json` (do not clobber)

- If the file does not exist, create it with the block above.
- If it exists, **merge**: set `permissions.defaultMode = "acceptEdits"` and **union** the `allow` array with any existing entries (dedupe). Preserve every other key the user already has.
- Validate the result is valid JSON before writing.

## Step 4 — Ensure it stays local

Make sure `.claude/settings.local.json` is gitignored in the target project (it should not be committed). If the project has a `.gitignore` and the entry is absent, append:

```
.claude/settings.local.json
```

## Step 5 — Tell the user it applies next session

Note in the summary that the pre-grant was written and **takes effect after restarting the Claude Code session** (the same restart needed for the generated `/d:task` and `/d:fix` to register).
