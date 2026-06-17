# /d:fix simulated-run checklist

Run after /d:init, on a trivial bug (e.g. "/health returns ok:false instead of ok:true").

- [ ] BEFORE any commit, a work branch d/fix/<slug> was created off trunkBranch (never committed on trunk)
- [ ] d-tester produced a diagnosis with reproduction + root cause before any fix was written
- [ ] a DIAGNOSIS CHECKPOINT was presented and confirmed before implementation (human stop)
- [ ] the fix was routed to the owning worker (d-backend for the /health bug) and is minimal/targeted
- [ ] d-tester added a regression test that reproduces the bug (fails pre-fix, passes post-fix)
- [ ] the test gate and quality gate each ran and reported pass/fail by script exit status
- [ ] on all-pass, a reflow step ran (root cause is a prime candidate) and the report listed which docs (if any) were reflowed
- [ ] a lightweight record was written to docs/specs/NNNN-fix-<slug>/ and specCounter bumped
- [ ] final report includes root cause, the fix, regression test, and gate results
- [ ] the run finished by opening a PR into trunkBranch (or pushing + printing PR instructions when no remote/gh); no commits landed on trunk
