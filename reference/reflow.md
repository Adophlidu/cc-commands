# reflow

Instructs the conductor (main agent running `/d:task` or `/d:fix`) how to keep the project's docs fresh as code evolves — without letting them bloat.

---

## When It Runs

Reflow executes at the **end** of a `/d:task` or `/d:fix` run, **after all gates pass** (lint, typecheck, tests, review). If any gate fails, reflow is skipped entirely; fix the failure first.

---

## Inputs — Candidate Learnings

During a run, the worker, tester, and ui agents each return a structured report. Reflow reads those reports and collects every item tagged as a **candidate learning**:

| Tag | Produced by | Examples |
|---|---|---|
| `architecture-change` | worker / d-pm | new module, new data-flow layer, added external dependency |
| `pitfall` | worker / tester / d-reviewer | race condition found, footgun in an API, test isolation trap |
| `convention` | worker / d-reviewer | naming pattern adopted, import style settled, error-handling decision |
| `ui-approach` | d-ui | new component pattern, layout heuristic, accessibility fix |

Agents surface candidates in their reports using a plain list under the heading **"Candidate learnings"**. No special schema is required — the conductor collects them by scanning each returned report for that heading.

---

## Durability Bar (Noise Filter)

A candidate is codified **only if all three conditions hold**. Drop it if any fails.

① **General** — will this recur across future tasks? One-file decisions that are unlikely to appear again are not general enough.

② **Not already documented** — dedupe against existing content in `docs/architecture/`, `docs/conventions.md`, and `docs/design.md`. If the docs already say it (even in slightly different words), drop the candidate.

③ **Stable** — not an in-progress experiment, a workaround with a known expiry, or a decision explicitly marked temporary in the PR/task description.

If a candidate fails any bar, the conductor silently drops it. No changelog entry, no comment — just omit it.

---

## Routing — Doc Owners

The conductor dispatches the appropriate subagent to integrate each candidate that clears the durability bar.

### Architecture changes, pitfalls, conventions → `d-pm`

`d-pm` owns `docs/architecture/` and `docs/conventions.md`. The conductor passes it:
- the list of cleared candidates (tagged `architecture-change`, `pitfall`, or `convention`)
- the current contents of the target doc(s) so it can integrate in place

`d-pm` edits the doc(s) directly. It does **not** append — see Lean Discipline below.

### UI approaches → `d-ui` (conditional)

`d-ui` owns `docs/design.md`. Before dispatching:

1. Read `d.manifest.json` → `uiBaseline.designSource`.
2. **If `designSource` is `null` or `"docs/design.md"`** (internal baseline): dispatch `d-ui` to integrate the UI learning into `docs/design.md`.
3. **If `designSource` is an external tool** (Figma URL, Stitch URL, or any `http*` URL): do **not** touch `docs/design.md`. Instead, surface the UI learning in the calling command's final report under **"UI learnings — reflect in [designSource]"** so the user can update the external source manually.

`docs/design.md` is **never created** by reflow — it must already exist (created by `/d:init`). If it is absent and `designSource` is internal, log a warning in the final report and skip the UI candidate.

---

## Lean Discipline — Edit, Don't Append

Both `d-pm` and `d-ui` must follow these rules when integrating:

- **Integrate in place.** Find the existing entry or section and rewrite it. Do not add a new section for every learning.
- **Supersede stale entries.** If a candidate contradicts an existing entry, replace the old entry with the new one. Never keep both sides of a contradiction.
- **Prune obsolete content.** If an existing entry describes something the codebase no longer does, remove it.
- **History lives in git.** Do not record "previously we did X, now we do Y." Write only the current truth.
- **Bullet points, not prose.** Match the tight reference style already in the doc.

Bloat in foundational docs (`docs/architecture/`, `docs/conventions.md`, `docs/design.md`) is a liability — every `d` agent reads these on every run. Keep them scannable.

---

## Auto-Commit and Surface

After `d-pm` and/or `d-ui` finish their edits:

1. The conductor stages and commits the changed doc files with a message of the form:
   ```
   docs: reflow after <task-id or fix-id>
   ```
2. The calling command's **final report** includes a section:
   ```
   ## Docs reflowed
   - docs/conventions.md — <one-line summary of what changed>
   - docs/architecture/overview.md — <one-line summary>
   ```
   If no docs were updated (all candidates dropped), the section reads:
   ```
   ## Docs reflowed
   No candidates cleared the durability bar.
   ```

No extra human checkpoint is required. The commit is automatic.

---

## Conductor Checklist

Before dispatching reflow, verify:

- [ ] All gates (lint / typecheck / tests / review) passed.
- [ ] Collected candidate learnings from all agent reports.
- [ ] Applied the durability bar — dropped any that fail ①②③.
- [ ] Checked `uiBaseline.designSource` before routing UI candidates.
- [ ] Dispatched `d-pm` with architecture / pitfall / convention candidates (if any).
- [ ] Dispatched `d-ui` with UI candidates (if any, and if `designSource` is internal).
- [ ] Committed changed docs and listed them in the final report.
