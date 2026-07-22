# Forge — sequential build pipeline plugin

7 specialized agents · right-sized models & effort · 1 slash command.

When you say *"build X"*, Forge runs **plan → design → code → test → review → security → deploy** in order.
Each phase uses the model and reasoning effort best suited to its job — Fable 5 for the
judgment phases (plan, design, review), Opus 4.8 for the security gate, Sonnet 5 for the
execution phases (code, test, deploy). You stay in the loop at the natural pause points
(after plan, after design, before deploy).

## Why this exists

Most coding agent runs are spent doing 5 jobs sequentially with one model. That wastes
money on the easy parts and under-thinks the hard parts. Forge enforces the lifecycle
and right-sizes the model.

| Phase | Agent | Model | Effort | Output |
|---|---|---|---|---|
| Plan | `forge-planner` | **Fable 5** | xhigh | `plan.md` with checkboxes |
| Design | `forge-designer` | **Fable 5** | xhigh | Stitch mockups + tokens, human-approved |
| Code | `forge-coder` | **Sonnet 5** | max | files edited / created |
| Test | `forge-tester` | **Sonnet 5** | medium | tests passing |
| Review | `forge-reviewer` | **Fable 5** | xhigh | findings + auto-fix safe items |
| Security | `forge-security` | **Opus 4.8** | max | `security-findings.md` (CVEs, secrets, SAST) |
| Deploy | `forge-deployer` | **Sonnet 5** | medium | URL + status |

Fable 5 runs the ideation/judgment phases (plan, design, review) at xhigh effort. Opus 4.8
takes the security gate at max effort — high-stakes triage, once per build. Sonnet 5 runs
the execution phases (code at max, test and deploy at medium), keeping one model across most
of the execution half to maximize prompt-cache reuse.

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
git clone https://github.com/h3nryprod01/claude-forge && cd claude-forge
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
2. Spawns `forge-designer` → mocks every UI surface in Google Stitch. **Pauses for your OK.** (Skipped for no-UI tasks.)
3. Spawns `forge-coder` → implements the plan against the approved designs.
4. Spawns `forge-tester` → writes & runs tests.
5. Spawns `forge-reviewer` → critical review; auto-applies LOW / MEDIUM fixes; surfaces HIGH / CRITICAL.
6. Spawns `forge-security` → scans deps + codebase for CVEs, secrets, SAST findings. **Halts only if it finds CRITICAL / HIGH.**
7. **Pauses for your OK before deploy.**
8. Spawns `forge-deployer` → ships.
9. Writes `.forge/<id>/state.json` done.

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
    ├── security-findings.md
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
    "plan":     { "status": "done", "model": "fable",  "agent": "forge-planner",  "ended": "..." },
    "design":   { "status": "done", "model": "fable",  "agent": "forge-designer", "ended": "..." },
    "code":     { "status": "in_progress", "model": "sonnet", "agent": "forge-coder", "started": "..." },
    "test":     { "status": "pending" },
    "review":   { "status": "pending" },
    "security": { "status": "pending" },
    "deploy":   { "status": "pending" }
  }
}
```

## Customizing models

Edit `agents/forge-*.md` frontmatter:

```yaml
---
name: forge-coder
description: ...
model: claude-sonnet-5   # pin an exact ID (claude-opus-4-8, claude-sonnet-5, claude-fable-5) or an alias (opus, sonnet, haiku, fable)
effort: max              # low | medium | high | xhigh | max — reasoning depth for this phase
---
```

Pin exact model IDs rather than the bare `opus`/`sonnet` aliases — an alias resolves to
whatever the current default is (e.g. `sonnet` → Sonnet 4.6), so pinning `claude-sonnet-5`
is what actually selects Sonnet 5. The `effort` field tunes reasoning depth per phase
(available levels depend on the model).

## When NOT to use Forge

- Throwaway one-liner edits (overhead too high)
- Pure research / Q&A (no code to ship)
- Tasks already mid-flight in a normal session (start fresh)

## License

MIT.
