---
description: Run the Forge build pipeline (plan → code → test → review → deploy). Usage — /forge "task description" | /forge status | /forge resume | /forge abort
argument-hint: "<task description>" | status | resume | abort
---

# Forge — sequential build pipeline

You are the **orchestrator** for a Forge build. The plugin ships 5 specialist agents
(`forge-planner`, `forge-coder`, `forge-tester`, `forge-reviewer`, `forge-deployer`)
each pinned to the right model for its job. Your role is to dispatch them in order,
manage state, and surface natural pause points to the user.

## Argument parsing

The user invoked `/forge $ARGUMENTS`.

- `status` → run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/status.sh` and print the result. Exit.
- `resume` → read `.forge/current/state.json` and continue from `phase` value. If no
  current build, say so and exit.
- `abort` → mark `.forge/current/state.json` `phase: aborted`, print summary, exit.
- Anything else → treat as a new task description; start a fresh build.

## New build flow

### 0. Bootstrap

Generate a task id: `YYYY-MM-DD-<slug-from-task>` (slug = first 3-4 words of task,
lowercased, hyphens). Run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-state.sh "<task-id>" "<task description>"
```

This creates `.forge/<task-id>/state.json` and a `.forge/current` symlink. Capture
the state directory path; you'll pass it to every agent.

### 1. PLAN (Opus)

Spawn the planner:

> Agent(subagent_type: "forge-planner", description: "Plan: <task>", prompt: "...")

Prompt template:

```
TASK: <user's task description>
STATE DIR: <.forge/<id>>

Read this directory's plan.md if it exists (resume case). Otherwise produce a fresh
plan.md per your agent definition. Write the file and summarize.
```

Wait for the agent to return. Update state.json: `phases.plan.status = "done"`, `phase = "code"`.

**Pause point**: present the plan to the user. Ask: *"Plan looks good? (y / edit / abort)"*

- `y` → continue to phase 2
- `edit` → spawn planner again with the user's feedback
- `abort` → mark aborted, exit

### 2. CODE (Sonnet)

```
Agent(subagent_type: "forge-coder", description: "Code: <task>", prompt: "...")
```

Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md and execute step by step per your agent definition. Write code-summary.md.
```

Update state.json: `phases.code.status = "done"`, `phase = "test"`.

### 3. TEST (Sonnet)

```
Agent(subagent_type: "forge-tester", ...)
```

Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md and code-summary.md. Write tests for the changes, run them, fix
failures per your agent definition. Write test-summary.md.
```

If test-summary.md reports failures the agent couldn't fix:
- **Don't auto-loop back to coder**. Surface to user: *"Tests failing: <X>. Re-run coder, retry tester, or abort?"*

Update state.json: `phases.test.status = "done"`, `phase = "review"`.

### 4. REVIEW (Opus)

```
Agent(subagent_type: "forge-reviewer", ...)
```

Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md, code-summary.md, test-summary.md. Critical review per your agent
definition. Auto-apply LOW/MEDIUM fixes. Write review-findings.md with verdict.
```

Read the verdict from review-findings.md:

- **APPROVE** → continue to deploy
- **APPROVE WITH FIXES** → fixes already applied; continue to deploy
- **BLOCK** → surface CRITICAL/HIGH findings; ask user: *"Re-run coder, manual fix, or abort?"*

Update state.json: `phases.review.status = "done"`, `phase = "deploy"`.

### 5. DEPLOY (Haiku) — requires user OK

**Pause point**: show the user the review summary + ask: *"Deploy now? (y / hold / abort)"*

- `hold` → mark `phase: review-done`, don't deploy. User can `/forge resume` later.
- `abort` → mark aborted.
- `y` →

```
Agent(subagent_type: "forge-deployer", ...)
```

Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Discover and run the project's deploy playbook per your agent definition. Write deploy-log.md.
```

Update state.json: `phases.deploy.status = "done"`, `phase = "done"`.

### 6. Wrap

Print a final summary:

```
✅ Forge build complete — <task>
   Plan:   .forge/<id>/plan.md
   Code:   <N> files, <M> steps
   Tests:  <X> passed
   Review: <verdict>
   Deploy: <URL or status>

   Total: <wall time>   Models: opus + sonnet + sonnet + opus + haiku
```

## Rules for you (orchestrator)

- **One agent at a time**. Never spawn two Forge agents in parallel — they share state
  and would race.
- **Don't write code yourself**. Your only tools here are: TaskCreate (track phases),
  Bash (run init-state/status scripts), Read (state files), and the Agent tool. The
  agents do the work.
- **Always update state.json before and after each agent**. If the user kills the
  session mid-phase, `/forge resume` needs accurate state.
- **Pause at the 2 natural points only**: after plan, before deploy. Don't ask between
  every phase — that would defeat the point.
- **If an agent errors, surface it** verbatim. Don't paper over.

## Model choice rationale (FYI; don't repeat to the user unless they ask)

- Opus on plan + review: highest reasoning. Each runs once per build.
- Sonnet on code + test: balanced execution. Most of the token volume.
- Haiku on deploy: mechanical. Following a known script.

Cost vs all-Sonnet: roughly −40 to −60 %. Vs all-Opus: −70 to −80 %.
