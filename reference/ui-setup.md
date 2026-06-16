# UI Setup Reference (`d-ui`)

**Applies to:** Projects whose role roster includes `d-ui`.  
**Skipped entirely** when `d-ui` is absent from the roster.

---

## Execution Model

Interaction is **main-agent-driven**. The main agent running `/d:init` must ask
the user all questions directly — subagents cannot prompt the user interactively.
Once preferences are collected, the main agent delegates only the non-interactive
authoring work (writing `docs/design.md`) to the `d-ui` subagent.

---

## Step 1 — Main Agent Asks: "How is UI handled?"

Present the user with two options:

1. **External design tool** (Figma, Stitch, or other) — the tool is the source of truth.
2. **AI decides UI** — the agent generates a design document from user preferences.

---

## Branch A — External Tool (Figma / Stitch / other)

### 1. Identify the tool

Ask the user which tool they use (e.g., Figma, Stitch, a custom URL).

### 2. Detect MCP availability

Use `ToolSearch` to check whether the matching MCP server is available:

- **Figma** → search for `figma` MCP tools (e.g., `mcp__plugin_figma_figma__get_design_context`).
- **Stitch** → search for a `stitch` MCP tool set.
- **Other** → search for a tool set matching the stated tool name.

If the MCP is **not available**, do not proceed. Instead:

> "The [Tool] MCP is not connected. Please bind/connect the [Tool] MCP server
> and re-run `/d:init`, or switch to AI-generated UI."

Halt UI setup until the MCP is reachable.

### 3. Collect the source reference

Ask the user for the canonical resource locator:

- Figma → a `figma.com` file or frame URL.
- Stitch → the project identifier or URL.
- Other → whatever canonical reference that tool uses.

### 4. Write manifest fields

```jsonc
{
  "uiBaseline": {
    "mode": "design",
    "designSource": "<figma url | stitch | ...>",
    "tool": "<playwright | backstopjs>"   // see Step 3
  }
}
```

### CRITICAL — No `docs/design.md`

When the external tool is the source of truth, **do NOT generate `docs/design.md`**.
The external tool (Figma, Stitch, etc.) is the **sole source of truth** for all
visual decisions. Generating a local design doc would create a conflicting
authority and must be avoided.

---

## Branch B — AI Decides UI

### 1. Main agent collects preferences (interactive)

Ask the user each of the following; accept brief or partial answers:

| Question | Examples |
|---|---|
| Visual style / aesthetic | minimal, playful, enterprise, brutalist |
| Tone | professional, friendly, technical, casual |
| Primary color or palette hint | brand hex, "cool blues", "earth tones" |
| Density | compact, comfortable, spacious |
| Reference products / inspiration | "like Linear", "like Stripe dashboard" |
| Any hard constraints | accessibility level, dark-mode requirement |

### 2. Delegate authoring to `d-ui` subagent

Pass the collected preferences + project context to the `d-ui` subagent with
the instruction to write `docs/design.md`. The subagent must cover:

- **Aesthetic & tone** — overall visual language and personality.
- **Typography** — type scale, font families, weight usage, line-height.
- **Color system** — primary, secondary, semantic (success/warning/error/info),
  surface, and background tokens.
- **Layout & spacing** — grid system, spacing scale, breakpoints.
- **Density** — touch targets, padding defaults, content density setting.
- **Component rules** — border radius, shadow/elevation levels, icon style,
  input and button conventions.
- **Motion** — transition duration and easing defaults (if applicable).

The subagent combines user preferences + project requirements + best practices.
It must not ask the user any questions; all necessary input arrives via the
prompt from the main agent.

### 3. Write manifest fields

```jsonc
{
  "uiBaseline": {
    "mode": "design",
    "designSource": "docs/design.md",
    "tool": "<playwright | backstopjs>"   // see Step 3
  }
}
```

---

## Step 3 — Record Visual Gate Tool (`uiBaseline.tool`)

Ask the user (or default silently) which visual regression tool to use:

- `playwright` — default; no extra dependency.
- `backstopjs` — opt-in; better for pixel-level screenshot diffing.

Record the choice in `uiBaseline.tool` in the manifest.

---

## Step 4 — Visual Gate (Later Workflows)

After UI setup is complete, the `d-ui` subagent participates in task and fix
workflows as a **visual gate**:

- It reads `designSource` from the manifest.
- If `designSource` is a Figma / Stitch URL, it fetches the current design
  via the appropriate MCP tool and compares it against the implementation.
- If `designSource` is `docs/design.md`, it loads that file and checks the
  implementation against the written spec.
- Deviations are reported as blocking issues before a task is marked done.

---

## Summary of Manifest Keys

| Key | Branch A value | Branch B value |
|---|---|---|
| `uiBaseline.mode` | `"design"` | `"design"` (source is the local `docs/design.md`) |
| `uiBaseline.designSource` | Figma URL / `"stitch"` / other | `"docs/design.md"` |
| `uiBaseline.tool` | `"playwright"` or `"backstopjs"` | same |

`docs/design.md` is created **only** in Branch B.
