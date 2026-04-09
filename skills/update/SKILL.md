---
name: couch-potato:update
description: Update the Couch Potato workflow files in this project to the latest plugin version.
---

# /couch-potato:update

Update the Couch Potato files installed in this project. Fetches the remote changelog, shows the user what changed since their installed version, updates the project-side agent definitions and Team Lead SKILL.md, and bumps `version` in `.couch/config.json`.

Workflow, protocol, schemas, and SOUL defaults live only in the plugin tree and are read by agents via `${CLAUDE_PLUGIN_ROOT}` — no project-side copy exists, so there is nothing to "re-copy" on update. `/reload-plugins` picks up the new plugin content after it has been installed by `claude plugin install`.

**Known coupling**: Step 2 hard-codes `https://raw.githubusercontent.com/glitchboyl/couch-potato/main/CHANGELOG.md`. If the plugin is renamed or forked, this URL must be updated in lockstep.

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

> "You're running the multi-agent-mode workflow. Your Claude Code now supports agent teams. Want to switch to team-mode for better coordination? A mode switch just flips the `mode` field in `.couch/config.json` and regenerates the project-side `SKILL.md` from the team-mode SKILL-body. No other files change — agents read the mode from config at runtime. [Y/N]"

Set `mode_switch_offered: true` in `.couch/config.json` immediately after prompting (regardless of the user's answer), so this prompt does not repeat on future update runs.

- **If yes**: set `mode: "team-mode"` in `.couch/config.json` and regenerate `.claude/skills/couch-potato/SKILL.md` from `${CLAUDE_PLUGIN_ROOT}/references/team-mode/SKILL-body.md`.
- **If no**: proceed without mode change.

**If the environment still does not satisfy team-mode requirements**: skip the prompt.

---

## Step 6 — Classify and apply file updates

For each file in the classification table below, apply the appropriate update behavior.

### File classification table

| Source path (under `${CLAUDE_PLUGIN_ROOT}/`) | Destination path (under project) | Category |
|---|---|---|
| `agents/architect.md` | `.claude/agents/architect.md` | Verbatim |
| `agents/researcher.md` | `.claude/agents/researcher.md` | Verbatim |
| `agents/coder.md` | `.claude/agents/coder.md` | Verbatim |
| `agents/tester.md` | `.claude/agents/tester.md` | Verbatim |
| `agents/retrospective.md` | `.claude/agents/retrospective.md` | Verbatim |
| — | `.claude/skills/couch-potato/SKILL.md` | Customizable |
| — | `.couch/config.json` | Customizable |
| — | `CLAUDE.md` | Customizable |

**Nothing else is copied into the project.** Workflow, protocol, schemas, SOUL defaults, hook scripts, and `config.schema.json` all live in the plugin tree and are read by agents via `${CLAUDE_PLUGIN_ROOT}` at runtime. There is no project-side copy to keep in sync.

**`${CLAUDE_PLUGIN_DATA}/souls/` is NEVER touched by update.** It holds the user's editable SOUL overrides. Init seeds it once from the plugin defaults; update leaves it alone forever.

### Verbatim files

Write automatically without prompting. Overwrite the existing file in the project.

### Customizable files

For each customizable file that exists in the project:
1. Show the diff between the current file and the incoming version.
2. Prompt: `[Y] overwrite  [N] keep mine  [D] show diff again`
3. Apply the user's choice. If [N], leave the file unchanged.

For `.claude/skills/couch-potato/SKILL.md`, the "incoming version" is `${CLAUDE_PLUGIN_ROOT}/references/<installed-mode>/SKILL-body.md`.

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
