---
name: couch-potato:update
description: Update the Couch Potato workflow files in this project to the latest plugin version.
---

# /couch-potato:update

Update the Couch Potato workflow files installed in this project. Fetches the remote changelog, shows the user what changed since their installed version, applies verbatim files automatically, and prompts for customizable files before writing.

---

## Step 1 — Read installed config

Read `.couch/config.json` from the current project root. Extract:

- `version` — the installed plugin version (semver string, e.g. `"3.2.0"`)
- `mode` — the installed workflow mode (`"team-mode"` or `"multi-agent-mode"`)

If `.couch/config.json` does not exist or `version` is missing, abort with:

> "Could not find .couch/config.json or it is missing the `version` field. Has /couch-potato:init been run in this project?"

---

## Step 2 — Fetch remote changelog

Fetch the remote CHANGELOG.md:

```
https://raw.githubusercontent.com/glitchboyl/couch-potato/main/CHANGELOG.md
```

If the fetch fails (network unreachable, non-200 response, timeout), abort with a clear error message. Do not proceed without the changelog — the update flow depends on it to determine what changed.

---

## Step 3 — Parse changelog delta

Parse CHANGELOG.md by scanning for `## [X.Y.Z]` headings (Keep a Changelog format). Extract all version entries whose version is strictly greater than the installed `version` (semver comparison).

Edge cases:
- If the installed version is not found in CHANGELOG.md, treat it as very old and show the full changelog.
- If no entries are newer than the installed version, inform the user they are up to date and exit cleanly.
- Ignore malformed headings (lines that look like `## [...]` but whose bracket content is not valid semver).

---

## Step 4 — Present delta to user

Before making any file changes, display the parsed changelog entries to the user. Format example:

```
Couch Potato update available: 3.2.0 → 3.3.0

## [3.3.0] - 2026-05-01
### Added
- ...
### Changed
- ...

Proceed with update? [Y/N]
```

If the user declines, exit cleanly with no files written.

---

## Step 5 — Mode-aware branching

Read the `mode` field from `.couch/config.json`.

### Case A — mode is `team-mode`

Run normal update logic (Steps 6–8) for team-mode files only.

### Case B — mode is `multi-agent-mode`

Re-check the current environment:
1. Detect Claude Code version.
2. Check whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in the environment or in `.claude/settings.json`.

**If the environment now satisfies team-mode requirements (v2.1.32+ AND flag set)**:

Check `mode_switch_offered` in `.couch/config.json`. If `mode_switch_offered` is `true`, skip this prompt (it has already been offered; respect the user's earlier choice). Otherwise:

Prompt once:

> "You're running the multi-agent-mode workflow. Your Claude Code now supports agent teams. Want to switch to team-mode for better coordination? This replaces workflow.md, protocol.md, SKILL-body.md, and souls/ with team-mode versions. [Y/N]"

Set `mode_switch_offered: true` in `.couch/config.json` immediately after prompting (regardless of the user's answer), so this prompt does not repeat on future update runs.

- **If yes**: install team-mode workflow files (overwrite the multi-agent-mode files with their team-mode counterparts from `${CLAUDE_PLUGIN_ROOT}/references/team-mode/`). Update `mode` to `"team-mode"` in `.couch/config.json`. Then run normal update logic for team-mode files.
- **If no**: run normal update logic for multi-agent-mode files only.

**If the environment still does not satisfy team-mode requirements**: skip the prompt, run normal update logic for multi-agent-mode files.

---

## Step 6 — Classify and apply file updates

For each file in the classification table below (filtered by installed mode), apply the appropriate update behavior.

### File classification table

| Source path (under `${CLAUDE_PLUGIN_ROOT}/`) | Destination path (under project) | Category | Mode scope |
|---|---|---|---|
| `references/team-mode/workflow.md` | `.claude/skills/couch-potato/references/team-mode/workflow.md` | Verbatim | team-mode installs |
| `references/team-mode/protocol.md` | `.claude/skills/couch-potato/references/team-mode/protocol.md` | Verbatim | team-mode installs |
| `references/team-mode/SKILL-body.md` | `.claude/skills/couch-potato/references/team-mode/SKILL-body.md` | Verbatim | team-mode installs |
| `references/team-mode/souls/` (all files, iterated) | `.claude/skills/couch-potato/references/team-mode/souls/` | Verbatim | team-mode installs |
| `references/multi-agent-mode/workflow.md` | `.claude/skills/couch-potato/references/multi-agent-mode/workflow.md` | Verbatim | multi-agent installs |
| `references/multi-agent-mode/protocol.md` | `.claude/skills/couch-potato/references/multi-agent-mode/protocol.md` | Verbatim | multi-agent installs |
| `references/multi-agent-mode/SKILL-body.md` | `.claude/skills/couch-potato/references/multi-agent-mode/SKILL-body.md` | Verbatim | multi-agent installs |
| `references/multi-agent-mode/souls/` (all files, iterated) | `.claude/skills/couch-potato/references/multi-agent-mode/souls/` | Verbatim | multi-agent installs |
| `references/schemas.md` | `.claude/skills/couch-potato/references/schemas.md` | Verbatim | both modes |
| `hooks/restrict_write_path.sh` | `.claude/skills/couch-potato/hooks/restrict_write_path.sh` | Verbatim | both modes |
| `references/config.schema.json` | `.couch/config.schema.json` | Verbatim | both modes |
| `agents/architect.md` | `.claude/agents/architect.md` | Verbatim | both modes |
| `agents/researcher.md` | `.claude/agents/researcher.md` | Verbatim | both modes |
| `agents/coder.md` | `.claude/agents/coder.md` | Verbatim | both modes |
| `agents/tester.md` | `.claude/agents/tester.md` | Verbatim | both modes |
| `agents/retrospective.md` | `.claude/agents/retrospective.md` | Verbatim | both modes |
| — | `.claude/skills/couch-potato/SKILL.md` | Customizable | both modes |
| — | `.couch/config.json` | Customizable | both modes |
| — | `.claude/agents/*.md` (user-added agents) | Customizable | both modes |
| — | `CLAUDE.md` | Customizable | both modes |

**Soul files: do not hardcode the file list.** Iterate the source souls directory at runtime:
- For team-mode: iterate `${CLAUDE_PLUGIN_ROOT}/references/team-mode/souls/` and copy each `.md` file found.
- For multi-agent-mode: iterate `${CLAUDE_PLUGIN_ROOT}/references/multi-agent-mode/souls/` and copy each `.md` file found (this includes `team-lead.md`, which does not exist in the team-mode souls directory).

**`${CLAUDE_PLUGIN_DATA}/souls/` is NEVER overwritten.** This directory contains the user's editable soul copies. The update skill writes only to the project-side `.claude/skills/couch-potato/references/<mode>/souls/` paths, which are the verbatim reference copies used as defaults before user customization. If a file exists in `${CLAUDE_PLUGIN_DATA}/souls/`, it is the user's customized version and must not be touched during any update operation.

### Verbatim files

Write automatically without prompting. Overwrite the existing file in the project.

### Customizable files

For each customizable file that exists in the project:
1. Show the diff between the current file and the incoming version.
2. Prompt: `[Y] overwrite  [N] keep mine  [D] show diff again`
3. Apply the user's choice. If [N], leave the file unchanged.

---

## Step 7 — Atomic version bump

After **all** file writes have succeeded, update the `version` field in `.couch/config.json` to the new version string (the highest version parsed from the remote changelog that is greater than the previously installed version).

Do not write the new version until all file operations complete successfully. If any file write fails, abort and report which file failed. The `version` field must remain at the old value so the next update attempt starts from a consistent state.

Also persist any changes to `mode` or `mode_switch_offered` made during Step 5 in the same `.couch/config.json` write.

---

## Step 8 — Restart reminder

After the version bump is written, print:

> "Couch Potato updated to vX.Y.Z. Run /reload-plugins in this session to load the updated plugin, or restart Claude Code."

---

## Field name contract

`.couch/config.json` field names used by this skill (must match task-002 schema doc and /couch-potato:init verbatim):

| Field | Type | Description |
|---|---|---|
| `mode` | string | `"team-mode"` or `"multi-agent-mode"` |
| `version` | string | Semver string of the installed plugin version |
| `mode_switch_offered` | boolean | `true` after the mode-switch prompt has been shown once (Case B) |
