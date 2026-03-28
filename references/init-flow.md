# Init Flow

Executable instructions for the Couch Potato setup init phase. This file is read and followed by Claude during project initialization.

Prerequisites: `stacks.md` (stack detection heuristics) and `claude-md-guide.md` (CLAUDE.md assessment/generation) in this same directory. Reference them — do not duplicate their content.

---

## 0. Manual Setup Check

Before running scans, check if the user explicitly requested manual setup (e.g., said "manual setup", "skip detection", or "I'll configure manually").

If manual setup is requested:
1. Skip all scans (Section 2).
2. Present an empty adaptation plan template with all fields set to placeholder values.
3. Let the user fill in each field directly via the confirmation flow (Section 4).
4. Proceed to Section 4 with the user-provided values.

---

## 1. Bootstrap Detection

Determine the orchestration mode by trying capabilities in order. Use the first mode that succeeds.

### Mode A — Agent Teams (full)

1. Attempt to call `TeamCreate` (any valid invocation).
2. If the tool exists and responds without error → use **Agent Teams mode**.
3. In this mode, all scan tasks (Section 2) run as named team members in parallel.

### Mode B — Parallel Subagents

1. If `TeamCreate` is unavailable or errors → attempt to call `Agent` tool with a trivial prompt (e.g., `"echo ready"`).
2. If the `Agent` tool exists and responds → use **Parallel Subagent mode**.
3. In this mode, each scan task (Section 2) is dispatched as an independent `Agent` call. All four run in parallel.

### Mode C — Single-Agent Sequential

1. If neither `TeamCreate` nor `Agent` is available → use **Sequential mode**.
2. Execute each scan task (Section 2) one at a time in the main context.
3. This is the slowest path but always works.

### Detection Implementation

```
try TeamCreate → success → Mode A
catch → try Agent → success → Mode B
catch → Mode C
```

Store the detected mode in a variable for later reference. Announce the mode to the user:

> Orchestration mode: [Agent Teams | Parallel Subagents | Sequential]

---

## 2. Scan Subagent Definitions

Four independent scan tasks. Each has a defined prompt, target files, and expected output schema. In Mode A/B, run all four in parallel. In Mode C, run sequentially A → B → C → D.

### Scan A — Stack Detection

**Goal**: Identify language, framework, package manager, and monorepo status.

**Prompt**:
> Detect the project's tech stack. Follow the heuristics in `references/stacks.md` exactly:
> 1. Scan project root for manifest files (Section 1 priority order).
> 2. Identify the lock file to determine the package manager (Section 2).
> 3. Read manifest dependencies to detect the framework (Section 3).
> 4. Check for monorepo indicators (Section 4).
> 5. If ambiguous (multiple manifests), report ALL detected stacks in the output — do NOT ask the user during the scan. Ambiguity is resolved in Section 4 (User Confirmation Flow) where the user reviews Item 1 (Stack).
>
> Return a structured result with these fields only.

**Files to read**: Project root files — `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `*.csproj`, `*.sln`, and all lock files listed in `stacks.md` Section 2.

**Expected output**:

| Field | Type | Example |
|-------|------|---------|
| `language` | string | `"Node.js"` |
| `framework` | string \| null | `"Next.js"` |
| `package_manager` | string | `"pnpm"` |
| `is_monorepo` | boolean | `true` |
| `monorepo_tool` | string \| null | `"Turborepo"` |

### Scan B — Project Structure

**Goal**: Map the directory layout, find source/config/test directories, detect dev server port and command.

**Prompt**:
> Map the project structure:
> 1. List top-level directories (2 levels deep).
> 2. Identify source directories (`src/`, `app/`, `lib/`, `components/`, `api/`, or equivalents).
> 3. Identify config directories and files (`.config/`, `config/`, `tsconfig.json`, `vite.config.*`, etc.).
> 4. Identify test directories (`test/`, `tests/`, `__tests__/`, `spec/`).
> 5. Read the manifest's scripts section (e.g., `package.json` `"scripts"`) to find:
>    - Dev server command and port
>    - Check/test command
>    - Lint command
>    - Build command
> 6. For monorepos: identify frontend and backend sub-package paths.
>
> Use defaults from `references/stacks.md` Section 5 only if actual commands cannot be determined.

**Files to read**: Run `ls` two levels deep. Read `package.json` scripts, `Makefile`, `justfile`, `pyproject.toml` scripts, `next.config.*`, `vite.config.*`.

**Expected output**:

| Field | Type | Example |
|-------|------|---------|
| `directory_layout` | string (tree) | `"apps/\n  frontend/\n  server/\npackages/\n..."` |
| `frontend_path` | string \| null | `"apps/frontend"` |
| `check_command` | string | `"pnpm type-check"` |
| `lint_command` | string | `"pnpm lint:fix"` |
| `dev_command` | string | `"pnpm dev"` |
| `dev_port` | number | `3000` |
| `build_command` | string | `"pnpm build"` |

### Scan C — Claude Code Setup

**Goal**: Assess existing Claude Code configuration and CLAUDE.md quality.

**Prompt**:
> Check the project's Claude Code setup:
> 1. Check if `.claude/` directory exists. If yes, list its contents.
> 2. Check for `.claude/settings.json` and `.claude/settings.local.json`.
> 3. Check for CLAUDE.md in all three locations per `references/claude-md-guide.md` Section 1 (Location Priority).
> 4. If a CLAUDE.md exists, assess it using the rubric in `references/claude-md-guide.md` Section 1 (Assessment Rubric). Score each of the 5 categories.
> 5. Check if Agent Teams is already configured (look for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in the `env` key of `.claude/settings.json` or `.claude/settings.local.json`).
>
> Return a structured result.

**Files to read**: `.claude/`, `.claude/settings.json`, `.claude/settings.local.json`, `CLAUDE.md`, `AGENTS.md`, `.claude/README.md`.

**Expected output**:

| Field | Type | Example |
|-------|------|---------|
| `has_claude_dir` | boolean | `true` |
| `has_settings` | boolean | `true` |
| `has_settings_local` | boolean | `false` |
| `has_claude_md` | boolean | `true` |
| `claude_md_location` | string \| null | `"CLAUDE.md"` |
| `claude_md_assessment` | object \| null | `{ "project_structure": "complete", "build_commands": "partial", ... }` |
| `teams_already_enabled` | boolean | `false` |

### Scan D — Existing Installation

**Goal**: Detect any prior Couch Potato or agent installation to avoid conflicts.

**Prompt**:
> Check for existing Couch Potato or agent installations:
> 1. Check if `.couch/` directory exists. If yes, list its contents.
> 2. Check if a Couch Potato skill already exists (look for `/couch-potato` in `.claude/commands/` or skill files).
> 3. Check for existing agent definitions (`.claude/agents/`, `.claude/teams/`, or agent config in settings).
> 4. Check if `codex` CLI is available (`which codex` or `codex --version`).
> 5. If conflicts are found, describe each one specifically.
>
> Return a structured result.

**Files to read**: `.couch/`, `.claude/commands/`, `.claude/agents/`, `.claude/teams/`. Run `which codex`.

**Expected output**:

| Field | Type | Example |
|-------|------|---------|
| `has_couch_dir` | boolean | `false` |
| `has_couch_potato_skill` | boolean | `false` |
| `has_agents` | boolean | `false` |
| `existing_agent_names` | string[] | `[]` |
| `has_codex` | boolean | `false` |
| `conflict_details` | string \| null | `null` |

---

## 3. Result Compilation

After all four scans complete, merge results into a single **adaptation plan**.

### Merge Procedure

1. Collect all four scan outputs into a single object with keys `stack`, `structure`, `claude_setup`, `installation`.
2. Cross-validate:
   - `stack.package_manager` should be consistent with `structure.dev_command` prefix (e.g., if package_manager is `pnpm`, dev_command should start with `pnpm`).
   - If `stack.is_monorepo` is true, `structure.frontend_path` must not be null. If it is, flag for user input.
3. Build the adaptation plan fields:

| Plan Field | Source | Fallback |
|-----------|--------|----------|
| `stack_label` | `stack.language` + `stack.framework` | `stack.language` alone |
| `check_command` | `structure.check_command` | Default from `stacks.md` Section 5 |
| `lint_command` | `structure.lint_command` | Default from `stacks.md` Section 5 |
| `dev_command` | `structure.dev_command` | Default from `stacks.md` Section 5 |
| `dev_port` | `structure.dev_port` | Default from `stacks.md` Section 5 |
| `build_command` | `structure.build_command` | Default from `stacks.md` Section 5 |
| `frontend_path` | `structure.frontend_path` | Project root (`"."`) |
| `claude_md_action` | Derived from user choice (see CLAUDE.md action flow) | `"generate"` |
| `settings_target` | `"settings.local.json"` if `claude_setup.has_settings` else `"settings.json"` | `"settings.json"` |
| `agent_conflict_action` | See conflict resolution below | `"none"` |
| `has_codex` | `installation.has_codex` | `false` |
| `confirmed` | Set to `true` when user confirms (Section 4) | `false` |

### Canonical Adaptation Plan Schema

The final adaptation plan object passed to the install phase has exactly these fields:

```json
{
  "stack_label": "string",
  "check_command": "string",
  "lint_command": "string",
  "dev_command": "string",
  "dev_port": "number",
  "build_command": "string",
  "frontend_path": "string",
  "claude_md_action": "skip | keep | patch | generate",
  "settings_target": "settings.json | settings.local.json",
  "agent_conflict_action": "none | merge | overwrite | skip | update | clean",
  "has_codex": "boolean",
  "confirmed": "boolean"
}
```

### Conflict Resolution (Existing Agents)

When `installation.has_agents` is true or `installation.has_couch_potato_skill` is true:

| Scenario | Options |
|----------|---------|
| Existing Couch Potato skill found | **Update** (overwrite with new version) or **Skip** (keep existing) |
| Existing non-Couch-Potato agents found | **Merge** (keep existing, add Couch Potato agents alongside) or **Overwrite** (replace all) or **Skip** (don't install agents) |
| Existing `.couch/` directory found | **Update** (merge config, preserve requirements) or **Clean** (delete and recreate) |

Default recommendation: **Merge** for agents, **Update** for existing Couch Potato. Present options to user in the confirmation flow (Section 4).

### CLAUDE.md Action Derivation

The adaptation plan stores the user's chosen action (not the assessment status). Derive the default recommendation from the assessment, then let the user override in Section 4.

| Assessment Result | Default Action | Meaning |
|-------------------|---------------|---------|
| All 5 categories = complete | `"keep"` | No changes needed |
| 1-2 categories = partial | `"patch"` | Will patch missing sections (show diff to user) |
| Any category = minimal | `"generate"` | Will generate from template per `claude-md-guide.md` Section 2 |
| No CLAUDE.md found | `"generate"` | Will generate from template per `claude-md-guide.md` Section 2 |

Canonical action values: `skip`, `keep`, `patch`, `generate`. The user selects the final value in the confirmation flow (Section 4, Item 6).

---

## 4. User Confirmation Flow

Present the compiled adaptation plan as a numbered list. The user can confirm all, change individual items, or abort.

### Display Format

```
Detected configuration:
1. Stack: <stack_label>
2. Check command: <check_command>
3. Lint command: <lint_command>
4. Dev server: <dev_command> (port <dev_port>)
5. Frontend path: <frontend_path>
6. CLAUDE.md: <claude_md_action> — <brief details>
7. Settings target: <settings_target>
8. Existing agents: <agent_conflict_action> — <details if any>

[C] Confirm all  |  [number] Change specific item  |  [A] Abort
```

### Handling User Input

**[C] Confirm all**: Lock in all values and proceed to the installation phase.

**[number] Change specific item**: Present item-specific options.

- **Item 1 (Stack)**: Show detected value and ask for correction. Free-text input accepted.
- **Item 2 (Check command)**: Show detected value. User can type a replacement command.
- **Item 3 (Lint command)**: Show detected value. User can type a replacement command.
- **Item 4 (Dev server)**: Show command and port separately. User can change either or both.
- **Item 5 (Frontend path)**: Show detected path. User can type a replacement path. Validate the path exists.
- **Item 6 (CLAUDE.md)**: Show the assessment details and current action. Options:
  - If default is `"keep"`: `[K] Keep as-is | [P] Patch missing sections | [G] Regenerate from scratch | [S] Skip`
  - If default is `"patch"`: `[P] Show and apply patches | [K] Keep as-is | [G] Regenerate from scratch | [S] Skip`
  - If default is `"generate"`: `[G] Generate from template | [S] Skip (not recommended)`
  - The user's choice sets `claude_md_action` to one of: `skip`, `keep`, `patch`, `generate`.
- **Item 7 (Settings target)**: Toggle between `settings.json` and `settings.local.json`. Explain the difference:
  > `settings.json` — shared with team (committed to git). Use if the whole team uses Claude Code.
  > `settings.local.json` — personal only (gitignored). Use if only you use Claude Code.
- **Item 8 (Existing agents)**: Show conflict details and present resolution options per Section 3 conflict resolution table.

After any change, redisplay the full list with the updated value highlighted and prompt again:

```
[C] Confirm all  |  [number] Change another item  |  [A] Abort
```

**[A] Abort**: Stop the init flow. Do not write any files. Inform the user they can re-run the setup later.

### Language Routing

- All user-facing text (prompts, options, status messages) — match the user's language.
- All internal values (commands, paths, field names) — always English.
- Detect the user's language from their first message. If unclear, default to English.

### Post-Confirmation

Once the user confirms, the adaptation plan is finalized. Pass the locked plan to the installation phase (defined in `setup.md`). The plan object contains all fields from Section 3 with user-approved values.
