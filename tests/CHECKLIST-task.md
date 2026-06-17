# /d:task simulated-run checklist

Run after /d:init, on a trivial requirement (e.g. "add a /version endpoint returning the app version").

- [ ] BEFORE any commit, a work branch d/task/0001-<slug> was created off trunkBranch (never committed on trunk)
- [ ] d-pm wrote docs/specs/0001-<slug>/spec.md with sub-tasks, acceptance criteria, and (since fullstack) an API contract
- [ ] manifest specCounter bumped to 1
- [ ] a SPEC CHECKPOINT was presented before any implementation (human stop)
- [ ] d-tester produced real test cases for the acceptance criteria
- [ ] the three gates each ran and reported pass/fail by script exit status
- [ ] on all-pass, a reflow step ran and the report listed which docs (if any) were reflowed
- [ ] final report includes spec path, changes, three-gate results
- [ ] the run finished by opening a PR into trunkBranch (or pushing + printing PR instructions when no remote/gh); no commits landed on trunk
