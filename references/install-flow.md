# Install Flow

Executable instructions for the Couch Potato install phase. This file is consumed by Claude after the user confirms the adaptation plan from `init-flow.md`.

Input: a locked adaptation plan object with user-approved values for stack, commands, paths, CLAUDE.md action, settings target, and existing-agent resolution.

---

## 1. Pre-install Checks

Before writing any files, verify all preconditions.

### Checks

1. **Adaptation plan confirmed** — The plan object must have `confirmed: true` (set by the confirmation flow in `init-flow.md` Section 4). If not confirmed, abort with: `"No confirmed adaptation plan. Run the init flow first."`

2. **Write permissions** — Attempt to create a temporary file at `<project_root>/.couch-potato-write-test`. If it fails, abort with: `"Cannot write to project directory. Check file permissions."`
   - Delete the test file immediately after the check. This tests at the project root because `.couch/` may not exist yet.

3. **Setup package readable** — Verify the setup package `templates/` directory is accessible. Check that these paths exist:
   - `templates/skill/SKILL.md`
   - `templates/agents/` (directory with at least one `.md` file)
   - `templates/config.schema.json`
   - If any are missing, abort with: `"Setup package templates not found at <path>. Ensure the couch-potato-setup package is intact."`

If all checks pass, proceed to Section 2.

---

## 2. Staging

Write all files to `.couch/.staging/` before touching any final locations. This enables atomic install and clean rollback.

### Staging Directory Structure

```
.couch/.staging/
  skill/                  -> final: .claude/skills/couch-potato/
    SKILL.md
    references/
      workflow.md
      protocol.md
      schemas.md
      souls/
        architect.md
        researcher.md
        coder.md
        tester.md
        challenger.md
        retrospective.md
  agents/                 -> final: .claude/agents/
    architect.md
    researcher.md
    coder.md
    tester.md
    retrospective.md
  skills/                 -> final: .claude/skills/ (optional)
    codex-bridge/
      SKILL.md
  config.json             -> final: .couch/config.json
  proposals_log.json      -> final: .couch/proposals_log.json
  manifest.json           -> consumed during install, then deleted
```

### Steps

1. **Create staging directory**: `mkdir -p .couch/.staging/`

2. **Copy skill templates**: Copy the entire `templates/skill/` tree into `.couch/.staging/skill/`. Preserve directory structure exactly.

3. **Copy agent templates**: Copy all files from `templates/agents/` into `.couch/.staging/agents/`.

4. **Codex bridge** (conditional): If the adaptation plan has `has_codex: true`, copy `templates/skills/codex-bridge/` into `.couch/.staging/skills/codex-bridge/`. If `has_codex: false`, skip this entirely.

5. **Generate config.json**: Build `.couch/.staging/config.json` from the adaptation plan:

   ```json
   {
     "version": "3.0.0",
     "skill": "couch-potato",
     "server_ports": {
       "dev": <plan.dev_port>
     },
     "project_path": ".",
     "frontend_path": <plan.frontend_path or ".">,
     "check_command": <plan.check_command>,
     "lint_command": <plan.lint_command>,
     "build_command": <plan.build_command>,
     "dev_command": <plan.dev_command>,
     "policy": {
       "enable_fast_track": true,
       "review_prompt_required": true,
       "model_resolution_priority": ["user_override", "complexity_rule", "task_model", "agent_default"],
       "default_requires_verification_by_type": {
         "code": true,
         "refactor": true,
         "i18n": false,
         "style": false,
         "test": false
       }
     }
   }
   ```

   If the plan includes an existing config to merge (`agent_conflict_action = "merge"`), read the existing `.couch/config.json` first. Keep existing values for any field that is already set; only fill missing fields from the plan. The `version` field always updates to `"3.0.0"`.

6. **Generate proposals_log.json**: Write `.couch/.staging/proposals_log.json` with content: `{"proposals":[]}`

7. **Write manifest.json**: List every staged file and its intended final path:

   ```json
   {
     "files": [
       { "staged": ".couch/.staging/skill/SKILL.md", "target": ".claude/skills/couch-potato/SKILL.md" },
       { "staged": ".couch/.staging/agents/architect.md", "target": ".claude/agents/architect.md" },
       ...
       { "staged": ".couch/.staging/proposals_log.json", "target": ".couch/proposals_log.json" }
     ],
     "directories": [
       ".couch/requirements/",
       ".couch/retrospectives/"
     ],
     "config": {
       "staged": ".couch/.staging/config.json",
       "target": ".couch/config.json"
     }
   }
   ```

   Every file in `.couch/.staging/` (except `manifest.json` itself) must appear in the manifest.

---

## 3. Validation

Verify the staging area before committing to the install.

### Checks

1. **Manifest completeness**: Read `manifest.json`. For every entry in `files`, verify the `staged` path exists and is non-empty. If any file is missing, abort with the list of missing files.

2. **Config validity**: Read `.couch/.staging/config.json`. Validate against `config.schema.json`:
   - Required fields: `version` (string), `skill` (string).
   - `server_ports` values must be integers 1-65535.
   - `check_command` and `lint_command` must be non-empty strings if present.
   - `frontend_path` must be a valid relative path (no leading `/`, no `..`).
   - If validation fails, list each violation and abort.

3. **No unresolved placeholders**: Scan `.couch/.staging/config.json` only for the pattern `<[A-Za-z_]+>` (angle-bracket placeholders). If any are found, list them and abort. Template `.md` files are copied verbatim and intentionally contain tokens like `<req-id>`, `<task-id>`, `<title>` — do NOT scan them for placeholders.

If all checks pass, proceed to Section 4.

---

## 4. Atomic Install

Move staged files to their final locations.

### Backup

Before overwriting any existing file, create a backup:
- Copy the existing file to `<filename>.bak.<timestamp>` in the same directory.
- Timestamp format: `YYYYMMDD-HHMMSS` (e.g., `config.json.bak.20260328-143022`).
- Record each backup in a `backups` list for potential rollback (Section 10).

### File Installation

Process the manifest in order:

1. **Create target directories** if they don't exist:
   - `.claude/skills/couch-potato/` and its subdirectories
   - `.claude/agents/`
   - `.claude/skills/codex-bridge/` (only if codex bridge is staged)
   - `.couch/requirements/`
   - `.couch/retrospectives/`

2. **Install files from manifest**:
   - For each entry in `manifest.files`: copy `staged` to `target`.
   - For agents specifically: if the adaptation plan says `merge`, do NOT delete existing files in `.claude/agents/` — only add or overwrite files that are in the manifest. If `overwrite`, clear the directory first (after backing up).

3. **Install config**:
   - Copy `.couch/.staging/config.json` to `.couch/config.json` (backup existing first if present).
   - Copy `.couch/.staging/proposals_log.json` to `.couch/proposals_log.json` (backup existing first if present).

4. **Create empty directories** listed in `manifest.directories` if they don't already exist.

If any file copy fails, immediately jump to Section 10 (Rollback).

---

## 5. Gitignore Update

Ensure `.gitignore` has the correct entries for Couch Potato.

### Must be gitignored

Add these lines if not already present:
```
.couch/requirements/
.couch/.staging/
```

### Must NOT be gitignored

Verify these are NOT matched by any gitignore pattern:
- `.couch/config.json`
- `.couch/retrospectives/`

If they are matched (e.g., by a broad `.couch/` pattern), warn the user but do NOT modify existing entries:
> Warning: `.couch/config.json` is currently gitignored by an existing pattern. This file should be committed so your team shares the same agent config. Please adjust your .gitignore manually to allow it.

### Implementation

1. Read `.gitignore` (create if it doesn't exist).
2. Check if the `# Couch Potato` comment block already exists in the file. If it does, skip the entire append and move to the 'Must NOT be gitignored' verification. Otherwise, check for existing entries and only ADD lines that are missing.
3. Append new entries at the end, preceded by a comment:
   ```
   # Couch Potato
   .couch/requirements/
   .couch/.staging/
   ```
4. **Never modify or remove any existing gitignore entries.** Only append new lines.

---

## 6. Settings Update

Update the Claude Code settings file to enable Agent Teams.

### Target File

Use the file the user selected in the adaptation plan:
- `settings_target = "settings.json"` -> `.claude/settings.json`
- `settings_target = "settings.local.json"` -> `.claude/settings.local.json`

### Procedure

1. Read the target file. If it doesn't exist, start with `{}`.
2. Parse as JSON.
3. Set `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"1"`:
   ```json
   {
     "env": {
       "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
     }
   }
   ```
4. **Preserve all existing settings.** Deep-merge: if `env` already has other keys, keep them. If other top-level keys exist, keep them.
5. Write the merged JSON back to the file with 2-space indentation.

If the file already has `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`, skip the write entirely.

---

## 7. CLAUDE.md Update

Apply CLAUDE.md changes based on the user's confirmed choice from the adaptation plan.

### Action: `skip` or `keep`

No changes. Skip this section.

### Action: `patch`

1. Read the existing CLAUDE.md (at the location identified in init-flow Scan C).
2. Identify which categories scored `partial` in the assessment.
3. For each partial category, generate the missing content using the corresponding section from `claude-md-guide.md` Section 2 template. Fill placeholders from the adaptation plan values.
4. Present the diff to the user:
   > The following sections will be added/updated in your CLAUDE.md:
   > [show the additions]
   > Apply these changes? [Y/n]
5. Only write if the user approves.

### Action: `generate`

1. Generate a complete CLAUDE.md from the template in `claude-md-guide.md` Section 2.
2. Fill all placeholders from the adaptation plan and scan results.
3. Present the full generated file to the user:
   > Generated CLAUDE.md for your project. Review and approve:
   > [show full file]
   > Write this file? [Y/n]
4. Only write if the user approves.

### Couch Potato Section

After the base CLAUDE.md is approved (whether existing, patched, or generated), append the Couch Potato compatibility section from `claude-md-guide.md` Section 3. Fill the build command placeholders from the adaptation plan:
- `<check_command>` -> `plan.check_command`
- `<lint_command>` -> `plan.lint_command`
- `<dev_command>` -> `plan.dev_command`
- `<build_command>` -> `plan.build_command`

Do NOT append if the section already exists in the file (check for the heading `## Couch Potato`).

---

## 8. Post-install Verification

Verify the installation is complete and functional.

### Checks

1. **File existence**: Glob for all expected files:
   - `.claude/skills/couch-potato/SKILL.md` — must exist
   - `.claude/agents/*.md` — must contain at least 5 files (architect, researcher, coder, tester, retrospective)
   - `.couch/config.json` — must exist
   - `.couch/requirements/` — must be a directory
   - `.couch/retrospectives/` — must be a directory
   - `.couch/proposals_log.json` — must exist and parse as valid JSON
   - If codex bridge was installed: `.claude/skills/codex-bridge/SKILL.md` — must exist

2. **Config readable**: Read `.couch/config.json` and verify it parses as valid JSON.

3. **Settings check**: Read the target settings file and verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is `"1"`.

### Reporting

Count files installed and report:
```
Verification: <N> files installed, config valid, settings updated.
```

If any check fails, do NOT rollback automatically. Report the specific failure and ask the user:
> Verification found issues:
> - [list failures]
> [R] Retry verification | [F] Fix manually | [B] Rollback installation

---

## 9. Cleanup

Remove the staging area after successful verification.

1. Delete `.couch/.staging/` and all its contents recursively.
2. Verify the directory is gone.

Do NOT clean up if verification failed — the staging files may be needed for debugging or manual recovery.

---

## 10. Rollback (on failure)

If any step in Sections 4-6 fails, execute this rollback procedure.

### Procedure

1. **Restore backups**: For each file in the `backups` list (recorded in Section 4), copy `<filename>.bak.<timestamp>` back to `<filename>`. Delete the backup copy after restoring.

2. **Remove newly created files**: For each file in the manifest that did NOT have a backup (i.e., it was a new file, not an overwrite), delete the target file.

3. **Remove newly created directories**: If the install created new directories (e.g., `.claude/skills/couch-potato/`) that did not exist before, remove them — but only if they are now empty. Never delete directories that contain files not created by this install.

4. **Revert gitignore**: If Section 5 appended lines, remove them. Only remove lines that were added in this session (identified by the `# Couch Potato` comment block).

5. **Revert settings**: If Section 6 modified the settings file, restore from the backup created before the write.

6. **Clean staging**: Delete `.couch/.staging/` entirely.

### Reporting

After rollback, report:
```
Installation rolled back. The following action failed:
- [step that failed]: [error message]

Files restored:
- [list of restored files]

Files removed:
- [list of removed files]

Your project is in its pre-install state. No Couch Potato files remain.
```

---

## 11. Post-install User Communication

After successful verification and cleanup, present a summary to the user.

### Message

```
Couch Potato installed successfully.

Written files:
- .claude/skills/couch-potato/  (skill + references)
- .claude/agents/               (5 agent definitions)
- .couch/config.json            (project configuration)
- .couch/requirements/          (created, gitignored)
- .couch/retrospectives/        (created)
[if codex] - .claude/skills/codex-bridge/  (Codex integration)

Modified files:
- .gitignore                    (added Couch Potato entries)
- .claude/<settings_target>     (enabled Agent Teams)
[if CLAUDE.md changed] - <claude_md_location>  (<action taken>)

SOULs define each agent's cognitive style. They live in `.claude/skills/couch-potato/references/souls/`. You can customize them via `/couch-potato` — the Team Lead reads and applies SOULs when spawning agents.

Use /couch-potato to start your first requirement.

Please exit Claude Code and re-enter to pick up new settings.
```

### Language Routing

- All user-facing text: match the user's language (detected in init-flow).
- All file paths, JSON keys, and technical terms: always English.
