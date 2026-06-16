# /d:init incremental-refresh checklist

Run /d:init once on a fixture (creates manifest + docs + agents). Then hand-edit one agent file and add a docs/specs/0001-foo/ dir. Then run /d:init AGAIN.

- [ ] the second run detected the existing manifest and entered refresh mode (did not stop on the old stub, did not re-scaffold)
- [ ] docs/architecture/ and docs/conventions.md were updated in place (not wiped + recreated)
- [ ] the existing docs/specs/0001-foo/ dir was preserved untouched
- [ ] the hand-edited agent file was NOT silently overwritten — the run asked before replacing it (or left it intact)
- [ ] manifest lastAnalyzedCommit was bumped to current HEAD; initializedAt unchanged; specCounter unchanged
- [ ] the run reported what was refreshed vs preserved
