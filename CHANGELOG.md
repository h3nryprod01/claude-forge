# Changelog

All notable changes to Forge are documented in this file. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [0.5.0] — 2026-07-01

### Changed

- **`forge-deployer` moved from Haiku to `claude-sonnet-5`** (Sonnet 5). Deploy is
  mechanical, but running it on the same model as the rest of the execution half of the
  pipeline (code, test, security) keeps prompt-cache reuse high and avoids a model swap for
  the final step — at Sonnet 5's intro pricing the cost delta over Haiku is small.
- The pipeline now uses just two tiers: **Opus 4.8** for the two reasoning gates (plan,
  review) and **Sonnet 5** for everything else (code, test, security, deploy). Haiku is no
  longer used.
- Refreshed model tables, headings, and rationale in README.md and SKILL.md; updated the
  deploy phase label in init-state.sh and the pipeline descriptions in plugin.json /
  marketplace.json.

## [0.4.0] — 2026-07-01

### Changed

- **`forge-coder`, `forge-tester`, and `forge-security` now pinned to `claude-sonnet-5`**
  (Sonnet 5), up from the bare `sonnet` alias that resolved to Sonnet 4.6. Sonnet 5 reaches
  near-Opus quality on coding and agentic work at Sonnet pricing ($3/$15 per MTok, with a
  $2/$10 introductory rate through 2026-08-31), so the three execution phases move up a tier
  without changing the cost profile.
- Pinned the exact ID (`claude-sonnet-5`) rather than the `sonnet` alias — matching the
  0.2.0/0.3.0 decision to pin `claude-opus-4-8` — so the alias resolving to an older Sonnet
  can't silently downgrade these phases.
- **`forge-planner` and `forge-reviewer` stay on `claude-opus-4-8`** (Opus 4.8). Plan and
  review are the two gates where correctness matters most — Opus 4.8 remains state-of-the-art
  on long-horizon reasoning and bug-finding, and each runs only once per build.
- `forge-deployer` stays on Haiku (mechanical deploy work).
- Refreshed the model tables and rationale in README.md and SKILL.md, and the pipeline
  descriptions in plugin.json / marketplace.json.

## [0.3.0] — 2026-06-18

### Added

- `forge-security` agent (Sonnet 4.6) — a dedicated security/vulnerability scan
  phase between Review and Deploy. Scans dependencies for known CVEs (`npm audit`,
  `pip-audit`, `cargo audit`, `govulncheck`, `osv-scanner`), the tree for leaked
  secrets (`gitleaks` / `trufflehog`, grep fallback), and code for SAST findings
  (`semgrep`). Triages by real exploitability; writes `security-findings.md` with a
  CLEAN / BLOCK verdict.
- The scan is a conditional gate: CLEAN flows to the deploy pause; CRITICAL / HIGH
  halts and asks (re-run coder / accept risk / abort). Report-only — never
  auto-bumps dependencies or rotates secrets.
- `security` phase added to `state.json` (init-state.sh) and `/forge status`.

### Changed

- Pipeline is now **plan → code → test → review → security → deploy** (6 agents).
  Merges the security phase (was a parallel 0.2.0 line) with the `claude-opus-4-8`
  pin. Updated SKILL.md, README, plugin.json, and marketplace.json.
- `forge-planner` and `forge-reviewer` pinned to `claude-opus-4-8` (Opus 4.8) in the
  security variant too — it previously still used the unpinned `opus` alias, which
  resolved to Opus 4.5. Now Opus 4.8 everywhere.

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
