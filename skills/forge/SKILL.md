---
name: forge
description: Runs a sequential build pipeline (plan → design → code → test → review → security → deploy) with seven specialist agents pinned to right-sized models and effort (Fable 5 at xhigh for plan, design, and review; Opus 4.8 at max for security; Sonnet 5 for code, test, and deploy). The design phase renders a mockup of every UI surface (self-contained HTML/CSS, plus real shadcn/ui code when the stack calls for it) for human approval before any code is written (skipped for backend/no-UI tasks). Trigger when the user says "build X", "implement X", "ship X", "/forge", "forge build", or asks to run a full feature lifecycle. Also handles subcommands "status", "resume", and "abort" for an in-flight build.
---

# Forge — sequential build pipeline

You are the **orchestrator**. Seven specialist agents do the actual work, each
pinned to the right model and reasoning effort for its job:

| Phase    | Agent              | Model    | Effort |
| -------- | ------------------ | -------- | ------ |
| Plan     | `forge-planner`    | Fable 5  | xhigh  |
| Design   | `forge-designer`   | Fable 5  | xhigh  |
| Code     | `forge-coder`      | Sonnet 5 | max    |
| Test     | `forge-tester`     | Sonnet 5 | medium |
| Review   | `forge-reviewer`   | Fable 5  | xhigh  |
| Security | `forge-security`   | Opus 4.8 | max    |
| Deploy   | `forge-deployer`   | Sonnet 5 | medium |

Your job: dispatch them in order, manage `.forge/<id>/state.json`, and surface
the three natural pause points (after plan, after design, before deploy). The
**design** phase renders every UI layout as an approvable mockup (self-contained
HTML, styled with the project's shadcn tokens when applicable) so a human can verify
the look before any code is written; it is skipped automatically for tasks with no UI.

## Argument handling

The user's request is in `$ARGUMENTS`.

- `status` → run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/status.sh` and print. Exit.
- `resume` → read `.forge/current/state.json` and continue from its `phase`
  field. If no current build, say so and exit.
- `abort` → mark `.forge/current/state.json` `phase: aborted`, summarize, exit.
- Anything else → treat as a new task description; start a fresh build.

## New build — eight steps

### 0. Bootstrap state

Generate a task id: `YYYY-MM-DD-<slug>` (slug = first 3-4 words of the task,
lowercased, hyphenated). Run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-state.sh "<task-id>" "<task description>"
```

This creates `.forge/<task-id>/state.json` and a `.forge/current` symlink.
Capture the state directory path — you'll hand it to every agent.

### 1. PLAN (Fable 5)

Spawn `forge-planner`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read this directory's plan.md if it exists (resume case). Otherwise produce
a fresh plan.md per your agent definition. Write the file and summarize.
```

Wait. Update `state.json` → `phases.plan.status = "done"`, `phase = "design"`.

**Pause point**: present the plan summary. Ask: *"Plan looks good? (y / edit / abort)"*

- `y` → continue
- `edit` → re-spawn planner with the user's feedback added to the prompt
- `abort` → mark aborted; exit

### 2. DESIGN (Fable 5) — render a mockup, then human verify

Read `plan.md`'s **## UI surfaces** section first to decide whether to run.

- **No UI surfaces** (it says `None — no UI in this task.`) → skip this phase.
  Set `phases.design.status = "skipped"`, `phase = "code"`, and go straight to
  CODE. Do **not** spawn the designer.
- **Has UI surfaces** → spawn `forge-designer`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md (especially ## UI surfaces). Detect the design mode (shadcn vs HTML),
design every listed layout as a self-contained HTML mockup with realistic mock data,
render each to a screenshot under <state-dir>/design/, and (mode C) scaffold the real
shadcn components under design/shadcn/. Write design-summary.md. Do NOT write app code.
```

Wait for the designer to finish. **Do not mark the phase done yet** — clear the
verify gate first, so `design` is only `done` once it's actually approved.

**Pause point (the verify gate)**: present the design summary + the rendered
screenshots under `.forge/<id>/design/`. Ask:
*"Designs look right? (y / regenerate <screen> with <change> / skip-design / abort)"*

- `y` → approved; continue to CODE — the coder builds against these designs.
- `regenerate <screen> with <change>` → re-spawn `forge-designer` with that change, then re-run this gate.
- `skip-design` → continue to CODE without binding to the designs.
- `abort` → mark aborted; exit.

Once design is **approved or skipped**, update `state.json` →
`phases.design.status = "done"` (or `"skipped"`), `phase = "code"`.

### 3. CODE (Sonnet 5)

Spawn `forge-coder`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md and execute step by step per your agent definition. If
design-summary.md exists and is approved, build the UI to match the approved
designs — use the tokens + per-screen HTML under design/, and the shadcn
components under design/shadcn/ if present.
Write code-summary.md.
```

Update state → `phases.code.status = "done"`, `phase = "test"`. No pause.

### 4. TEST (Sonnet 5)

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

### 5. REVIEW (Fable 5)

Spawn `forge-reviewer`. Prompt:

```
TASK: <task>
STATE DIR: <.forge/<id>>

Read plan.md, code-summary.md, test-summary.md. Critical review per your
agent definition. Auto-apply LOW/MEDIUM fixes. Write review-findings.md
with verdict.
```

Read the verdict from `review-findings.md`:

- **APPROVE** → continue to security
- **APPROVE WITH FIXES** → fixes already applied; continue
- **BLOCK** → surface CRITICAL/HIGH findings; ask: *"Re-run coder, manual fix, or abort?"*

Update state → `phases.review.status = "done"`, `phase = "security"`.

### 6. SECURITY SCAN (Opus 4.8)

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

### 7. DEPLOY (Sonnet 5) — pause first

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

### 8. Wrap

Print a final summary:

```
✅ Forge build complete — <task>
   Plan:     .forge/<id>/plan.md
   Design:   <N screens rendered | skipped — no UI>
   Code:     <N> files, <M> steps
   Tests:    <X> passed
   Review:   <verdict>
   Security: <CLEAN / BLOCK + count>
   Deploy:   <URL or status>
   Total:    <wall time>   Models: fable + fable + sonnet + sonnet + fable + opus + sonnet
```

## Orchestrator rules

- **One agent at a time.** Never spawn two Forge agents in parallel — they share state.
- **Don't write code yourself.** Use the Agent tool to dispatch. The agents have the
  right tool allowlists; you don't need to second-guess them.
- **Update state.json before and after each agent.** A killed session needs accurate
  state for `/forge resume`.
- **Pause at the 3 natural points only**: after plan, after design, before deploy.
  Don't ask between every phase — that defeats the point.
- **Skip the design phase when there's no UI.** Read `plan.md`'s UI surfaces; if
  none, mark `design` skipped and go to code. Never run the designer for backend tasks.
- **Surface agent errors verbatim.** Don't paper over.

## Model rationale (for your own decision-making; only repeat to the user if asked)

- Fable 5 at xhigh on plan + design + review = the judgment-heavy phases. Planning
  weighs tradeoffs, design turns intent into UI (and reviews the rendered mockups at
  the verify gate), and review is adversarial critique — all ideation/reasoning work,
  run at high effort where it pays off.
- Opus 4.8 at max on security = the last gate before deploy. Vulnerability triage
  is high-stakes judgment — worth the deepest-reasoning model at full effort, and
  it runs once per build.
- Sonnet 5 on code + test + deploy = the execution phases. Code runs at **max**
  effort (correctness-critical writing); test and deploy run at **medium** — enough
  to write and run tests and follow a known deploy script without overspending.
  Keeping one model across most of the execution half also maximizes prompt-cache
  reuse.

Retune by editing each agent's `model` + `effort` frontmatter.
