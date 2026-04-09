# Couch Potato

A self-organizing agent swarm for [Claude Code](https://claude.com/claude-code). You describe what you want built — the swarm handles planning, implementation, testing, and review.

## What it does

Couch Potato adds a **Team Lead** skill and 5 specialized agents to your project:

| Agent | Role |
|-------|------|
| **Architect** | Analyzes codebase, plans task breakdowns, reviews results |
| **Coder** | Claims tasks, implements code, self-verifies |
| **Tester** | Verifies changes with evidence, challenges assumptions |
| **Researcher** | Finds docs, evaluates source trustworthiness |
| **Retrospective** | Post-run analysis, proposes system improvements |

The Team Lead orchestrates everything. You talk to the Team Lead; it spawns and coordinates the agents.

Each agent has a **SOUL** — a cognitive style definition that shapes how it thinks, what it prioritizes, and what it deliberately ignores. SOULs create genuine functional complementarity, not just role labels.

## Why "couch potato"?

Because that's the job: lie on the couch, point agents at what you want, and let them handle the rest.

## How it works

```
You: "Add dark mode support"
         │
    ┌────▼────┐
    │Team Lead│  ← understands goal, builds team
    └────┬────┘
         │
    ┌────▼─────┐     ┌──────────┐
    │ Architect │────▶│ tasks.json│  ← plans tasks, maps dependencies
    └────┬─────┘     └──────────┘
         │
    ┌────▼────┐  ┌────────┐  ┌────────┐
    │ Coder 1 │  │Coder 2 │  │ Tester │  ← parallel execution
    └─────────┘  └────────┘  └────────┘
```

**Workflow**: Understand → Plan → Approve → Execute → Review → Complete

- Sequential gates with user approval at each phase
- Wave-based parallel execution with file ownership
- Built-in feedback loops (Correction Mode, Retrospective Agent)
- Cross-run learning via proposals log

## Install

### Workflow modes

Couch Potato installs in one of two modes depending on your environment:

**Team-mode** (recommended): agents communicate directly peer-to-peer using Claude Code's native agent teams feature. Requires Claude Code **v2.1.32+** with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set (in your environment or `.claude/settings.json`).

**Multi-agent-mode** (fallback): works on any Claude Code version. The main instance (Team Lead) is the sole orchestrator — all agent-to-agent discussion is relayed through main. No peer-to-peer agent threads; no parallel agent communication. Higher latency and higher main context usage than team-mode. The `/couch-potato:init` skill detects your environment and installs the right mode automatically.

### Persistent install (recommended)

Step 1 — Add the marketplace:

```bash
claude plugin marketplace add glitchboyl/couch-potato
```

Or from a local clone:

```bash
claude plugin marketplace add ./couch-potato
```

Step 2 — Install the plugin:

```bash
claude plugin install couch-potato@couch-potato
```

No restart required after install. Run `/reload-plugins` in an active session to activate.

Step 3 — Run the init skill in your project:

```
/couch-potato:init
```

The init skill detects your environment (Claude Code version, agent teams flag), selects team-mode or multi-agent-mode, and installs workflow files, agent definitions, and config.

### Dev loop (for plugin authors)

Clone this repo and launch Claude Code pointing at it:

```bash
claude --plugin-dir /path/to/couch-potato
```

Edits to plugin source files take effect in the next session — no re-install needed.

For snapshot install (simulates the real user experience):

```bash
claude plugin marketplace add /path/to/couch-potato
claude plugin install couch-potato@couch-potato
```

After any source change, re-run `plugin install` and `/reload-plugins`.

**Cache is authoritative.** Claude Code loads installed plugins from `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — not from this repo. Edits to source files have no effect until `plugin install` re-copies them into the cache. If a fix looks correct in source but `/reload-plugins` still errors, you are almost certainly staring at the old cached copy.

## Usage

After installation, invoke the swarm:

```
/couch-potato
```

Then describe what you want. The Team Lead handles the rest.

## What gets installed

```
.claude/
├── skills/couch-potato/       # Team Lead skill
│   └── SKILL.md               # Team Lead instructions
├── agents/                    # Agent definitions (5 files)
└── settings.json              # Agent Teams enabled

${CLAUDE_PLUGIN_DATA}/
└── souls/                     # Your editable agent cognitive styles

.couch/
├── config.json                # Project config (committed)
├── proposals_log.json         # Cross-run improvement tracking
├── retrospectives/            # Post-run analysis (committed)
└── requirements/              # Per-requirement state (gitignored)
```



### What init writes vs what the plugin serves

`/couch-potato:init` writes files **into your project**. The plugin itself ships a separate set of files that agents read directly from the plugin cache path. These two sets are distinct — confusing them is how you end up "fixing" source files that the runtime never loads, or declaring install complete because `config.json` exists while the `/couch-potato` command is still missing.

| Written by `/couch-potato:init` into the project | Shipped by the plugin (read from `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`) |
|---|---|
| `.couch/config.json` — project configuration | `agents/` — agent definitions (architect, coder, tester, researcher, retrospective) |
| `.claude/skills/couch-potato/SKILL.md` — **gate file for the `/couch-potato` slash command; without it the command is unavailable** | `skills/init/`, `skills/update/`, `skills/codex-bridge/` — the plugin's own skills |
| `.claude/agents/*.md` — agent copies | `hooks/` — `SessionStart` and `PreToolUse` hooks |
| `.couch/requirements/` (gitignored), `.couch/retrospectives/` | `references/` — workflow docs, protocol, schemas, SOUL defaults |
| CLAUDE.md Couch Potato stanza | |

## Supported stacks

Auto-detection works for:

- **Node.js** — Next.js, Nuxt, Angular, Vue, Svelte, Remix, Astro, Express, Fastify, Hono, NestJS
- **Python** — Django, Flask, FastAPI, Starlette
- **Go** — Gin, Echo, Fiber, Chi
- **Rust** — Actix Web, Axum, Rocket, Warp
- **Java/Kotlin** — Spring Boot, Quarkus, Micronaut
- **.NET** — ASP.NET Core

Monorepo detection: Turborepo, Nx, Lerna, pnpm/npm/yarn workspaces.

For unsupported stacks, use manual setup.

## Customization

- **SOULs** — Edit files in `${CLAUDE_PLUGIN_DATA}/souls/` to customize how agents think (created on first `/couch-potato:init`)
- **Config** — Edit `.couch/config.json` to adjust policies (fast-track, verification defaults, model selection)
- **Agent definitions** — Edit files in `.claude/agents/` to change tool access or model defaults

## Design principles

1. **Conditions over counters** — Loops exit when the goal is met, not after N rounds
2. **Failure is input** — Error output drives the next attempt, not blind retries
3. **Think Failure First** — Verify assumptions before building
4. **Constraints > instructions** — Hard rules enforced by tooling where possible
5. **Improve the system** — Retrospective Agent identifies patterns and proposes specific changes

## Versioning

The `VERSION` file at the repo root holds the current release version. `CHANGELOG.md` tracks all notable changes per version. This project follows [Semantic Versioning](https://semver.org/). Releases are tagged `vX.Y.Z` in git.

## License

MIT
