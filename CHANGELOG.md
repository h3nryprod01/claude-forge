# Changelog

All notable changes to Forge are documented in this file. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [0.2.0] — 2026-05-28

### Changed

- **`forge-planner` and `forge-reviewer` now pinned to `claude-opus-4-8`**
  (was the unpinned `opus` alias, which resolved to whatever Claude Code's
  current default was — typically Opus 4.5 or 4.7). Applies to both Claude
  Code and Cowork. Docs updated everywhere "Opus 4.5" appeared.

## [0.1.1] — 2026-05-28

### Changed

- Removed `commands/forge.md` (duplicate of `skills/forge/SKILL.md`). The skill
  is still invokable as `/forge` in Claude Code and auto-triggers on natural
  language in Cowork. Saves ~60 always-on tokens per session.

## [0.1.0] — 2026-05-28

### Added

- 5 specialist agents with model frontmatter:
  - `forge-planner` (Opus 4.5) — produces `plan.md` checklist
  - `forge-coder` (Sonnet 4.6) — executes the plan step by step
  - `forge-tester` (Sonnet 4.6) — writes & runs tests
  - `forge-reviewer` (Opus 4.5) — adversarial review, auto-applies LOW/MEDIUM fixes
  - `forge-deployer` (Haiku 4.5) — runs the project's deploy playbook
- Two entrypoints (Claude Code + Cowork compatible):
  - `commands/forge.md` — `/forge "task"` slash command
  - `skills/forge/SKILL.md` — auto-triggers on natural-language build requests
- State machine under `.forge/<task-id>/` with `state.json`, `plan.md`,
  `code-summary.md`, `test-summary.md`, `review-findings.md`, `deploy-log.md`
- Sub-commands: `/forge status`, `/forge resume`, `/forge abort`
- Pause points after plan and before deploy (no surprise deploys)
- `.claude-plugin/marketplace.json` for one-command install:
  `/plugin marketplace add h3nryprod01/claude-forge` then `/plugin install forge@claude-forge`
