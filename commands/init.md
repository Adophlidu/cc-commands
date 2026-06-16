---
description: Initialize d workflow for this project (spike build)
argument-hint: (none)
---
<!-- command-naming: verified /d:init. Evidence: `claude plugin install d@d-dev`
     succeeded and `claude plugin details d` lists the component as "init" under
     plugin "d" (installed at cache/d-dev/d/0.1.0/commands/init.md). Command name =
     filename minus .md (init); namespace = plugin.json name (d) => namespaced
     invocation /d:init. Cross-checked vs reference plugin commit-commands:
     commands/commit.md (no name field) => /commit and namespaced /commit-commands:commit.
     Layout: commands/init.md (flat). Confidence: high. -->

SPIKE: print exactly `D_INIT_REACHED` and stop. Do nothing else.
