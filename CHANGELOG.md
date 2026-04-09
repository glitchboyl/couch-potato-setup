# Changelog

All notable changes to this project will be documented in this file. Format: Keep a Changelog. Versioning: Semantic Versioning.

## [Unreleased]

## [3.5.0] - 2026-04-09

### Added

- Initialization gate ("Before you do anything else") in team-mode `SKILL-body.md` plus Bash-fallback trap and hook-blocked Situation bullet (req-011)
- Authorized bootstrap Situation and joint convergence-test standing diagnostic, captured in `.couch/retrospectives/req-012.md` (req-012)
- XML-fence pattern for injected prior-session context in both protocol.md files (req-013)
- Fact-verification rule for adversarial review — added to `agents/architect.md` Self-Awareness and both challenger SOULs (req-016)

### Changed

- `team_name` is now a freeform hint passed to `TeamCreate`; agents must capture and reuse the harness-returned slug for all downstream `Agent` spawns. `run.json` records both `requirement_id` and `team_slug`. Protocol.md step 8 rewritten to the capture-and-use pattern, landing req-009 Proposal A (req-017)
- Imported pre-existing v3.4.0 refactor: no project-side `references/` copy; SOUL paths, schema, and README updated accordingly (req-014)

### Fixed

- `init` writes the agent-teams flag to `settings.local.json` instead of the committed `.claude/settings.json` (req-015)
- Removed global `PreToolUse` hook registration and deleted dead `hooks/restrict_*_path.sh` scripts — plugin hooks can't be skill-scoped; frontmatter `disallowedTools` is the correct mechanism
- Three stale `{req-id}/config.json` path references corrected (req-017)

### Reverted

- req-015's `team_name MUST equal req-id` constraint — prevented no concrete failure mode and conflicted with the harness's global team namespace. Replaced by the capture-and-use rule above (req-017)

## [3.3.0] - 2026-04-08

### Removed

- `templates/skill/` and `templates/agents/` trees (canonical sources fully migrated to repo-root `skills/`, `hooks/`, `agents/`, `references/` in v3.2.0)
- `setup.md` legacy entry point
- `references/init-flow.md` and `references/install-flow.md` (superseded by `skills/init/SKILL.md`)

### Changed

- `templates/config.schema.json` → `references/config.schema.json` (relocated; only reference updated in `skills/update/SKILL.md` file-classification table)
- `templates/skills/codex-bridge/` → `skills/codex-bridge/` (now discoverable as a plugin skill)
- `README.md`: removed "Migrating from v3.1.0" subsection — migration path is simply `git checkout v3.1.0` in this repo
- `CLAUDE.md`: Structure diagram and Key paths updated to reflect plugin layout; removed `setup.md` / `templates/` references
- `references/stacks.md`: removed `init-flow.md` section reference
- `references/config.schema.json`: `stack` field description updated to reference the init-skill adaptation plan

### Breaking

- Anyone still invoking `Read setup.md and follow it` must first `git checkout v3.1.0` in this repo — the file no longer exists in 3.3.0. Recommended path: persistent plugin install per `README.md`.

## [3.2.1] - 2026-04-08

### Added

- `hooks/restrict_read_path.sh`: Read-path restriction hook restored to plugin tree, registered in `hooks/hooks.json` and both `references/team-mode/SKILL-body.md` and `references/multi-agent-mode/SKILL-body.md` frontmatter; honor-system narrative in "You don't write code" section replaced with harness-enforcement claim (task-001)

### Fixed

- `references/team-mode/SKILL-body.md`, `references/multi-agent-mode/SKILL-body.md`: PreToolUse Write matcher broadened from `Write` to `Write|Edit|MultiEdit` to match `hooks/hooks.json` (task-001)

### Changed

- `.claude-plugin/marketplace.json`: plugin version field `3.2.1` added per relative-path marketplace docs; `version` field removed from `.claude-plugin/plugin.json` (zero callers found — safe to remove per docs guidance) (task-002)
- `templates/agents/coder.md`, `agents/coder.md`: prop-001 applied — prohibition on rewriting narrative or documentation to mask broken or missing downstream state; escalate to Architect instead (task-003)
- `templates/skill/references/souls/coder.md`, `references/team-mode/souls/coder.md`, `references/multi-agent-mode/souls/coder.md`: prop-002 applied — new "Failure modes to avoid" bullet on constraint preservation during adaptation (task-004)
- `templates/agents/researcher.md`, `agents/researcher.md`: prop-003 applied — new Action Framework sub-step to scan docs warnings/gotchas/admonition sections when fetching documentation (task-005)
- `templates/skill/references/protocol.md`, `references/team-mode/protocol.md`: prop-004 applied — new `### If team state appears inconsistent or spawn errors` subsection under Initialization with protocol response steps (task-006)

## [3.2.0] - 2026-04-07

### Added

- `.claude-plugin/plugin.json`: plugin manifest registering `couch-potato` with `skills/`, `hooks/hooks.json`, and plugin metadata
- `.claude-plugin/marketplace.json`: marketplace manifest enabling persistent install via `claude plugin marketplace add`
- `skills/init/SKILL.md`: `/couch-potato:init` subcommand — three-case environment detection (team-mode, flag prompt, upgrade prompt), resume-after-restart via `.couch/setup-state.json`, SOUL persistence to `${CLAUDE_PLUGIN_DATA}/souls/`
- `skills/update/SKILL.md`: `/couch-potato:update` subcommand — semver changelog delta, verbatim/customizable file classification, mode-switch prompt for multi-agent users whose environment now supports team-mode
- `hooks/hooks.json`: hook registration file for SessionStart and PreToolUse hooks
- `hooks/session-start.sh`: SessionStart hook — checks GitHub for newer version and prints update notice; exits 0 silently on network failure
- `hooks/restrict_write_path.sh`: PreToolUse hook moved from `templates/skill/hooks/` to plugin-root `hooks/` for plugin layout
- `agents/`: agent definitions (architect, researcher, coder, tester, retrospective) at repo root for plugin layout
- `references/schemas.md`: shared schemas moved to repo-root `references/` for plugin layout
- `references/team-mode/`: team-mode workflow (workflow.md, protocol.md, SKILL-body.md, souls/) using native agent-team coordination
- `references/multi-agent-mode/`: multi-agent-mode workflow (workflow.md, protocol.md, SKILL-body.md, souls/) using hub-and-spoke orchestration; mode-specific Team Lead SOUL emphasizing relay fidelity

### Note

- Legacy `templates/skill/` tree retained for backward reference; full removal deferred to a follow-up

## [3.1.0] - 2026-04-07

### Added

- `templates/skill/hooks/restrict_write_path.sh`: PreToolUse hook script that reads tool input JSON from stdin and exits with code 2 for any file_path not under `.couch/`

### Changed

- `templates/skill/SKILL.md` rewritten in AGENTS.md style: replaced 18 Hard Constraints + 6 Principles with an operational manual structure (opening paragraph, 'You don't write code' section, per-phase Workflow with inline why, 'Situations you'll encounter' scenarios, SOUL section, References list)
- `templates/skill/SKILL.md` frontmatter updated: added `disallowedTools: Edit, Bash, Glob, Grep, ToolSearch, Skill` and `PreToolUse` hook on Write tool that invokes `hooks/restrict_write_path.sh` to block writes outside `.couch/`
- `templates/config.schema.json` updated: `server_ports` removed from `required`, new optional `stack` field added (string), `frontend_path` documented as optional and omitted for backend-only projects
- `references/install-flow.md` Section 2 Step 5 updated: generated config.json now omits `server_ports` when no dev_port, omits `frontend_path` when no frontend detected, includes `stack` field from adaptation plan
- `references/init-flow.md` Section 3 updated: adaptation plan persists `stack_label` into config.json as `stack` field
- `references/install-flow.md` updated: staging copies `templates/skill/hooks/` to `.claude/skills/couch-potato/hooks/`, manifest includes hook scripts, install step preserves executable permissions
- `templates/skill/references/protocol.md` updated: reuse-before-spawn rule replaced with simplified two-rule structure + concrete idle-check subsection (read team config + TaskList), model tier determination documented (4-level precedence, SendMessage non-re-resolution, Opus inheritance hazard, mandatory explicit model: rule), L-complexity opus upgrade rule and no-downgrade-below-frontmatter rule added

## [3.0.0] - 2026-03-28

### Added

- Initial setup package with `setup.md` as AI-driven install entry point
- `references/init-flow.md` and `references/install-flow.md`: phase-by-phase installation instructions
- `references/stacks.md`: tech stack auto-detection heuristics
- `references/claude-md-guide.md`: CLAUDE.md assessment rubric and generation templates
- `templates/skill/SKILL.md`: Team Lead skill definition
- `templates/skill/references/`: workflow, protocol, schemas, souls (architect, researcher, coder, tester, challenger, retrospective)
- `templates/agents/`: agent definitions (architect, researcher, coder, tester, retrospective)
- `templates/config.schema.json`: config validation schema
- `templates/skills/codex-bridge/`: optional Codex CLI integration skill
- `README.md`: project overview and install instructions

[Unreleased]: https://github.com/glitchboyl/couch-potato-setup/compare/v3.1.0...HEAD
[3.1.0]: https://github.com/glitchboyl/couch-potato-setup/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/glitchboyl/couch-potato-setup/releases/tag/v3.0.0
