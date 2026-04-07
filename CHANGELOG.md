# Changelog

All notable changes to this project will be documented in this file. Format: Keep a Changelog. Versioning: Semantic Versioning.

## [Unreleased]

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
