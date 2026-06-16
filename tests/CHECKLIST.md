# /d:init dogfood checklist (sample-fullstack)

- [ ] docs/architecture/overview.md exists and names the real stack (React + Hono) with cited paths (src/web, src/server)
- [ ] docs/conventions.md exists, merges tsconfig strict + inferred rules
- [ ] projectType resolved to "fullstack"
- [ ] .claude/agents/ contains d-pm, d-tester, d-reviewer, d-frontend, d-backend, d-ui (all six)
- [ ] each agent file has NO remaining {{SLOTS}}
- [ ] .claude/d/manifest.json is valid JSON with qualityGate.lint set and testGate.test set
- [ ] a calibration checkpoint was shown before generation
- [ ] green-baseline self-test ran the gate commands and reported pass
- [ ] .claude/commands/d/task.md was generated, starts with valid `---` frontmatter, and contains no remaining {{SLOTS}}
- [ ] the generated task.md references reading .claude/d/manifest.json and an absolute path to the plugin's reference/reflow.md (not a bare ${CLAUDE_PLUGIN_ROOT})
