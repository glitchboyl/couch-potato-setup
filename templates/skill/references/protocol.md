# Couch Potato — Protocol Reference

Part of the Couch Potato skill definition. See SKILL.md for Hard Constraints and Principles.

---

## Protocol Reference

### Initialization
1. Read `.couch/config.json`
2. `pwd` → PROJECT_ROOT
3. Generate `req-<NNN>` (check existing `.couch/requirements/` dirs)
4. Create `.couch/requirements/<req-id>/`
5. Detect active dev server — read ports from `.couch/config.json` `server_ports` (dev: 3100, production_local: 3111, test: 3112)
6. Note `frontend_path` from config (e.g. `apps/frontend`) — include in spawn prompts for agents working within the frontend module
7. Read `.couch/retrospectives/` for existing retrospective files. If `.couch/proposals_log.json` exists (schema: `schemas.md`), read it and filter for proposals with `status: accepted`. For each accepted proposal, note its `target_file` and `summary`. When spawning agents, include accepted proposals that target that agent's definition or SOUL file in the spawn prompt as context — e.g., "Note: an accepted improvement proposal affects your role: [summary]".
8. `TeamCreate` with `team_name: <req-id>` — this creates the shared task list and messaging channel for the swarm
9. Create `run.json` at `.couch/requirements/<req-id>/run.json` per schemas.md. Update `phase` at each workflow gate.

### Spawn Prompt Template
Roster agents MUST be spawned using their corresponding `subagent_type` from `.claude/agents/` — never substitute a roster role with a generic subagent type.

**Reuse before spawn**: Check for idle agents of the required type before spawning (Hard Constraints). If a match exists, SendMessage them instead. **Exception**: if the idle agent's last task failed or was escalated, spawn a fresh instance — a degraded context is unlikely to produce better results (see Principle 4: Failure is input).

Every permanent agent spawn includes: `team_name: <req-id>`, role, SOUL (read from `references/souls/<role>.md` and included verbatim), requirement ID + title, project root, dev server port, state dir (`.couch/requirements/<req-id>/`), relevant MCP tools, and "Check TaskList and start working."

For Coder spawns, additionally include the task's explicit file ownership list from `tasks.json` (`file_ownership`) — this defines the Coder's file access boundary for their claimed task. Also include the task's domain tags (e.g., "React, UI, API integration") to guide skill and tool discovery.

For temporary discussion agents: include the Challenger SOUL (`references/souls/challenger.md`). If `.claude/skills/codex-bridge/SKILL.md` exists, additionally include codex SKILL instructions. These are one-shot — they participate in a specific discussion and are not permanent team members.

For Retrospective Agent spawns, include the path to `.couch/proposals_log.json` so it can read existing proposals, check for duplicates, and update statuses (e.g., marking a proposal `applied` after it has been incorporated). Schema reference: `schemas.md`.

**User-facing communication**: Spawn configuration (SOUL, model, prompt content) is internal. Do not narrate agent configuration details to the user. Present agent activity externally using simple descriptions: "consulting the Architect", "starting implementation", "running verification" — not "spawning Architect with Structural Analyst SOUL using opus model on team req-017."

### Agent Roster
- **Architect** — structural analysis, task breakdown, acceptance review (spawned for planning, always). SOUL: `references/souls/architect.md`
- **Coder** — claims tasks, implements, self-verifies (1 per parallel track). SOUL: `references/souls/coder.md`
- **Tester** — verifies changes with evidence, challenges Coder and Architect (on-demand). SOUL: `references/souls/tester.md`
- **Researcher** — finds docs, evaluates source trustworthiness (on-demand). SOUL: `references/souls/researcher.md`
- **Retrospective Agent** — post-run pattern analysis, proposes system improvements (on-demand, one-shot; communicates only with Team Lead + Researcher). SOUL: `references/souls/retrospective.md`
- **Temporary Discussion Agent** — spawned for discussions needing model diversity. Uses Challenger SOUL + codex SKILL. Not a permanent team member.

### SOUL Design Rules
- SOULs must produce genuinely different attention patterns, not just different adjectives
- "What I deprioritize" is NOT a blind spot — agent should override if flagged critical
- The one-sentence stance is the internal capsule summary for role cognition — not for user-facing disclosure
- Retrospective Agent may propose SOUL patches; user must approve before applying

### Files
```
.claude/skills/couch-potato/
├── SKILL.md
└── references/
    ├── schemas.md
    ├── workflow.md
    ├── protocol.md
    └── souls/
        ├── architect.md
        ├── coder.md
        ├── tester.md
        ├── researcher.md
        ├── challenger.md
        └── retrospective.md

.claude/skills/codex-bridge/SKILL.md    # Codex CLI tool reference

.couch/
├── config.json
├── retrospectives/<req-id>.md
└── requirements/
    ├── <req-id>/
    │   ├── run.json
    │   ├── requirement.md
    │   ├── tasks.json
    │   └── test-reports/
    └── <req-id>-fix-<M>/          # Correction Mode teams
        ├── requirement.md
        ├── tasks.json
        └── test-reports/
```

### Schemas
Task plan schema and output templates: `.claude/skills/couch-potato/references/schemas.md`
