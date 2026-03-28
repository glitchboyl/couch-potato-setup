# Couch Potato — Workflow Reference

Part of the Couch Potato skill definition. See SKILL.md for Hard Constraints and Principles.

---

## Workflow

These are sequential gates — what happens between them is agent judgment.

**Understand** — Your first reading is a hypothesis, not a conclusion.

Explore: keep asking user until ~90% understood. Route by type:
- Code-touching requirement → spawn Architect for codebase context before presenting understanding to user. Discuss with user to clarify scope, constraints, desired outcome.
- Non-code requirement (external integration, process, config-only) → discuss with user directly. Spawn Architect only if structural questions arise.
- If stuck after multiple rounds → spawn additional agents: Researcher for external unknowns. For discussions needing model diversity, spawn temporary agent with Challenger SOUL. If codex-bridge skill is installed, also include codex SKILL instructions.
- For independent topics, use parallel one-shot subagents so perspectives are isolated.

Fast-track: if task is single-file, no architectural impact, and user explicitly confirms trivial → before dispatching, ask Architect (one-shot) to assess blast radius across these factors — any "high risk" → escalate to normal Plan workflow:
- **Dependent count**: >5 files import/reference this file → high risk
- **Export surface**: >3 exports → shared module, high risk
- **File category**: shared utility, hook, store slice, layout, routing config, or provider → high risk
- **State coupling**: reads/writes Zustand stores, React Context, or global state → high risk
- **Render tree position**: layout, provider wrapper, or route-level component → high risk

Otherwise, skip Plan phase and dispatch directly to a fresh Coder with: file path, acceptance criteria from user confirmation, and relevant context only. Still requires user approval of what will be done (inline, not via tasks.json). Fast-track completion: Coder reports done → user confirms the change is correct. No formal verification or test reports required.

Synthesize: combine user input + agent findings — weight disagreements and surprises over confirmations.

Present to user. Exit: user confirms understanding.

**Plan** — Requirement confirmed → give to Architect for task breakdown. Architect produces `requirement.md` (canonical spec) and `tasks.json` (task plan). Confirm which agents are needed per task. Exit: both `requirement.md` and `tasks.json` received; `tasks.json` validated per schemas.md validation rules.

**Approve** — Present the plan to the user:
- Scope summary (1-2 sentences)
- Task list with title, description summary, and acceptance criteria for each task
- Number of parallel execution tracks

Execution details (model assignments per task, wave strategy, file ownership) are available if the user asks — do not include by default. If the user wants to change which model handles a specific task, they can ask.

Exit: explicit user approval of the plan.

**Execute** — Create all tasks in TaskList with their dependencies. Execute waves in sequence:
1. Spawn Coder(s) for the current wave's tasks (one Coder per parallel track in the wave).
2. Monitor: relay escalations to user with context and options. Challenge scope deviations.
3. Wait for all tasks in the current wave to pass the Wave Exit Checklist (below) before spawning the next wave.

Spawn additional roles (Tester, Researcher) as the plan demands — independently of wave progress.

Plan amendment — for in-execution corrections (not scope expansion):
1. Coder or Architect identifies that the current plan needs adjustment (e.g., missed dependency, wrong file target, task split needed).
2. Architect produces a delta: what changes, what stays, and why.
3. Team Lead presents the delta to user for quick confirmation.
4. On approval, update TaskList and resume execution. On rejection, continue with the original plan.

### Wave Exit Checklist

Before advancing to the next wave (or exiting Execute after the final wave), verify ALL tasks in the current wave:

1. For each task in the wave:
   - If `requires_verification: true` → read the task's `expected_report_path` (a `.json` file). Must show `"status": "PASS"`.
   - If `requires_verification: false` → TaskList status `completed` is sufficient.
2. If any verified task shows `FAIL` or `BLOCKED` → do NOT advance. Present the failing report to the user and escalate.
3. If any task with `requires_verification: true` is missing its verification file → do NOT advance. The task is incomplete.
4. All tasks pass → proceed to the next wave (or exit Execute if this was the final wave).

**Review** — Ask user: "Would you like a formal review before wrapping up, or does this look good?" If review → Architect checks against acceptance criteria. An independent code review can also be run for additional perspective. Exit: review passed or user accepts as-is.

**Complete** — Present results (modified files, summaries, deviations). Remind user about `/commit`. If the run had any plan amendment, escalation, Correction Mode activation, or stagnation event (same error twice without new information), spawn Retrospective Agent. Ask user whether to keep the session open for follow-up changes, or close it out — do not auto-close.

## Correction Mode

If user provides corrections after completion: create a new team (`req-<NNN>-fix-<M>`), spawn Coder (+ Tester if needed). The fix team state must record `parent_requirement_id: <original-req-id>`, `correction_reason`, and the `original_task_ids` being revisited. Include correction history and original context in spawn prompts. Fix, verify, present, shutdown.

## Escalation

When agents escalate to you: present the situation to the user with context and options. You are a relay, not a decision-maker — the user decides.

Common triggers: agent disagreement on approach, scope change discovered mid-execution, user preference needed between viable alternatives, blocker that Researcher can't resolve.
