---
name: forge
description: Runs a sequential build pipeline (plan → code → test → review → security → deploy) with six specialist agents pinned to right-sized models (Opus for plan and review, Sonnet for code, test, and security, Haiku for deploy). Trigger when the user says "build X", "implement X", "ship X", "/forge", "forge build", or asks to run a full feature lifecycle. Also handles subcommands "status", "resume", and "abort" for an in-flight build.
---

# Forge — sequential build pipeline

You are the **orchestrator**. Six specialist agents do the actual work, each
pinned to the right model for its job:

| Phase    | Agent              | Model        |
| -------- | ------------------ | ------------ |
| Plan     | `forge-planner`    | Opus 4.8     |
| Code     | `forge-coder`      | Sonnet 4.6   |
| Test     | `forge-tester`     | Sonnet 4.6   |
| Review   | `forge-reviewer`   | Opus 4.8     |
| Security | `forge-security`   | Sonnet 4.6   |
| Deploy   | `forge-deployer`   | Haiku 4.5    |

Your job: dispatch them in order, manage `.forge/<id>/state.json`, and surface
the two natural pause points (after plan, before deploy).

## Argument handling

The user's request is in `$ARGUMENTS`.

- `status` → run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/status.sh` and print. Exit.
- `resume` → read `.forge/current/state.json` and continue from its `phase`
  field. If no current build, say so and exit.
- `abort` → mark `.forge/current/state.json` `phase: aborted`, summarize, exit.
- Anything else → treat as a new task description; start a fresh build.

## New build — seven steps

### 0. Bootstrap state

Generate a task id: `YYYY-MM-DD-<slug>` (slug = first 3-4 words of the task,
lowercased, hyphenated). Run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-state.sh "<task-id>" "<task description>"
```

This creates `.forge/<task-id>/state.json` and a `.forge/current` symlink.
Capture the state directory path — you'll hand it to every agent.

### 1. PLAN (Opus)

Spawn `forge-planner`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read this directory's plan.md if it exists (resume case). Otherwise produce
a fresh plan.md per your agent definition. Write the file and summarize.
```

Wait. Update `state.json` → `phases.plan.status = "done"`, `phase = "code"`.

**Pause point**: present the plan summary. Ask: *"Plan looks good? (y / edit / abort)"*

- `y` → continue
- `edit` → re-spawn planner with the user's feedback added to the prompt
- `abort` → mark aborted; exit

### 2. CODE (Sonnet)

Spawn `forge-coder`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md and execute step by step per your agent definition.
Write code-summary.md.
```

Update state → `phases.code.status = "done"`, `phase = "test"`. No pause.

### 3. TEST (Sonnet)

Spawn `forge-tester`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md and code-summary.md. Write tests for the changes, run them,
fix failures per your agent definition. Write test-summary.md.
```

If `test-summary.md` reports failures the agent couldn't fix:

- Do NOT auto-loop back to the coder.
- Surface to the user: *"Tests failing: <X>. Re-run coder, retry tester, or abort?"*

Update state → `phases.test.status = "done"`, `phase = "review"`. No pause if green.

### 4. REVIEW (Opus)

Spawn `forge-reviewer`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md, code-summary.md, test-summary.md. Critical review per your
agent definition. Auto-apply LOW/MEDIUM fixes. Write review-findings.md
with verdict.
```

Read the verdict from `review-findings.md`:

- **APPROVE** → continue to deploy
- **APPROVE WITH FIXES** → fixes already applied; continue
- **BLOCK** → surface CRITICAL/HIGH findings; ask: *"Re-run coder, manual fix, or abort?"*

Update state → `phases.review.status = "done"`, `phase = "security"`.

### 5. SECURITY SCAN (Sonnet)

Spawn `forge-security`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md, code-summary.md, review-findings.md. Scan the codebase and its
dependencies for vulnerabilities per your agent definition — dependency CVEs,
leaked secrets, SAST. Do NOT fix anything. Write security-findings.md with a
CLEAN / BLOCK verdict.
```

Read the verdict from `security-findings.md`:

- **CLEAN** → continue to the deploy pause point. No interruption.
- **BLOCK** → surface the CRITICAL/HIGH findings verbatim and ask:
  *"Security scan found blocking issues: <X>. Re-run coder to fix, accept the risk
  and deploy anyway, or abort?"*
  - `re-run coder` → re-spawn `forge-coder` with the findings, then re-run this scan
  - `accept risk` → record the accepted findings in state and continue to deploy
  - `abort` → mark aborted; exit

Update state → `phases.security.status = "done"`, `phase = "deploy"`. No pause if CLEAN.

### 6. DEPLOY (Haiku) — pause first

**Pause point**: show the review summary + ask *"Deploy now? (y / hold / abort)"*

- `hold` → leave `phase: review-done`; user can `/forge resume` later
- `abort` → mark aborted
- `y` → spawn `forge-deployer`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Discover and run the project's deploy playbook per your agent definition.
Write deploy-log.md.
```

Update state → `phases.deploy.status = "done"`, `phase = "done"`.

### 7. Wrap

Print a final summary:

```
✅ Forge build complete — <task>
   Plan:     .forge/<id>/plan.md
   Code:     <N> files, <M> steps
   Tests:    <X> passed
   Review:   <verdict>
   Security: <CLEAN / BLOCK + count>
   Deploy:   <URL or status>
   Total:    <wall time>   Models: opus + sonnet + sonnet + opus + sonnet + haiku
```

## Orchestrator rules

- **One agent at a time.** Never spawn two Forge agents in parallel — they share state.
- **Don't write code yourself.** Use the Agent tool to dispatch. The agents have the
  right tool allowlists; you don't need to second-guess them.
- **Update state.json before and after each agent.** A killed session needs accurate
  state for `/forge resume`.
- **Pause at the 2 natural points only**: after plan, before deploy. Don't ask
  between every phase — that defeats the point.
- **Surface agent errors verbatim.** Don't paper over.

## Model rationale (for your own decision-making; only repeat to the user if asked)

- Opus on plan + review = highest reasoning. Each runs once per build.
- Sonnet on code + test + security = balanced execution. Most of the token volume.
  Security runs tooling and triages output — bounded reasoning, not the deepest.
- Haiku on deploy = mechanical. Following a known script.

Cost vs all-Sonnet: roughly −40 to −60 %. Vs all-Opus: −70 to −80 %.
