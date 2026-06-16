# /d:init new-project checklist

Run on an EMPTY directory, with a described requirement (e.g. "a todo web app with accounts and a postgres DB").

- [ ] /d:init asked the user to describe the product (did not stop on the old stub)
- [ ] it read reference/better-t-stack.md and consulted `create-better-t-stack@latest --help`
- [ ] it constructed a non-interactive `npx create-better-t-stack@latest . --yes <flags>` command with valid flags matching the requirement (e.g. --database postgres --auth better-auth)
- [ ] it presented the command + per-choice rationale for ONE confirmation (human stop)
- [ ] after scaffolding (interactive-acceptance: actually run npx in a real session), it committed a baseline and fell through into the existing-project pipeline (Steps 3–14), producing docs, agents, manifest, and the /d:task + /d:fix commands
