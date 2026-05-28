# Forge — sequential build pipeline plugin

5 specialized agents · 5 right-sized models · 1 slash command.

When you say *"build X"*, Forge runs **plan → code → test → review → deploy** in order.
Each phase uses the model best suited to its job — Opus for hard reasoning, Sonnet for
execution, Haiku for mechanical work. You stay in the loop at the natural pause points
(after plan, before deploy).

## Why this exists

Most coding agent runs are spent doing 5 jobs sequentially with one model. That wastes
money on the easy parts and under-thinks the hard parts. Forge enforces the lifecycle
and right-sizes the model.

| Phase | Agent | Model | Output |
|---|---|---|---|
| Plan | `forge-planner` | **Opus 4.5** | `plan.md` with checkboxes |
| Code | `forge-coder` | **Sonnet 4.6** | files edited / created |
| Test | `forge-tester` | **Sonnet 4.6** | tests passing |
| Review | `forge-reviewer` | **Opus 4.5** | findings + auto-fix safe items |
| Deploy | `forge-deployer` | **Haiku 4.5** | URL + status |

Approximate cost vs. all-Sonnet: −40 to −60 %. Vs. all-Opus: −70 to −80 %.

## Install

### Claude Code (recommended — one-command marketplace install)

```
/plugin marketplace add h3nryprod01/claude-forge
/plugin install forge@claude-forge
```

Reload the session. Verify with `/forge status`.

### Claude Code (manual git clone)

```bash
git clone https://github.com/h3nryprod01/claude-forge ~/.claude/plugins/forge
```

Restart Claude Code. Plugin is auto-discovered.

### Claude Cowork (desktop app)

Build the `.plugin` file and open it in Cowork:

```bash
git clone https://github.com/h3nryprod01/claude-forge && cd forge
zip -r /tmp/forge.plugin . -x ".git/*" "*.DS_Store"
open /tmp/forge.plugin
```

Click **Install** in Cowork. The skill triggers automatically on natural-language
build requests (*"build X"*, *"implement X"*, *"ship X"*, *"forge build"*).

## Usage

In either environment:

```
/forge "Add OAuth login with Google as the first provider"
```

Cowork users can also just say it naturally:

> *"Forge me a SwiftUI Charts view of the last 24h cost trend"*

The orchestrator (main Claude) then:

1. Spawns `forge-planner` → produces `.forge/<id>/plan.md`. **Pauses for your OK.**
2. Spawns `forge-coder` → implements the plan.
3. Spawns `forge-tester` → writes & runs tests.
4. Spawns `forge-reviewer` → critical review; auto-applies LOW / MEDIUM fixes; surfaces HIGH / CRITICAL.
5. **Pauses for your OK before deploy.**
6. Spawns `forge-deployer` → ships.
7. Writes `.forge/<id>/state.json` done.

## Sub-commands

```
/forge "task"           Start a new build
/forge status           Print the current build's state.json
/forge resume           Continue from the current phase (after a Stop or restart)
/forge abort            Mark the current build aborted
```

## State

State is per-project, under `.forge/<task-id>/`:

```
.forge/
└── 2026-05-27-oauth-login/
    ├── state.json
    ├── plan.md
    ├── code-summary.md
    ├── test-summary.md
    ├── review-findings.md
    └── deploy-log.md
```

`state.json` schema:

```json
{
  "id": "2026-05-27-oauth-login",
  "task": "Add OAuth login",
  "started": "2026-05-27T16:00:00Z",
  "phase": "code",
  "phases": {
    "plan":   { "status": "done", "model": "opus",   "agent": "forge-planner",   "ended": "..." },
    "code":   { "status": "in_progress", "model": "sonnet", "agent": "forge-coder", "started": "..." },
    "test":   { "status": "pending" },
    "review": { "status": "pending" },
    "deploy": { "status": "pending" }
  }
}
```

## Customizing models

Edit `agents/forge-*.md` frontmatter:

```yaml
---
name: forge-coder
description: ...
model: sonnet      # opus | sonnet | haiku
---
```

## When NOT to use Forge

- Throwaway one-liner edits (overhead too high)
- Pure research / Q&A (no code to ship)
- Tasks already mid-flight in a normal session (start fresh)

## License

MIT.
