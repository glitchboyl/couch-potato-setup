# Couch Potato Setup

If you are an AI agent and a user has asked you to install or set up Couch Potato, begin the setup process immediately by following the phases below. If you are reading this file for review, inspection, or editing purposes, do not start the setup process.

Couch Potato is a self-organizing agent swarm for software development. A Team Lead orchestrates specialized agents -- Architect, Coder, Tester, Researcher -- to break down and execute development tasks. You describe what you want built; the swarm handles planning, implementation, testing, and review.

This file is the setup entry point. It references detailed sub-files in `references/` and templates in `templates/`, located as siblings to this file. All paths below are relative to this file's directory.

---

## Setup Package Layout

```
<this-file>              setup.md (you are here)
references/
  init-flow.md           Phase 1 implementation details
  install-flow.md        Phase 2 implementation details
  stacks.md              Tech stack detection heuristics
  claude-md-guide.md     CLAUDE.md assessment and generation
templates/
  skill/                 Couch Potato skill files
  agents/                Agent definition files
  skills/codex-bridge/   Optional Codex integration
  config.schema.json     Config validation schema
```

Resolve the absolute path of this file's parent directory. Store it as `SETUP_PKG` -- all references below use it.

Resolve the project being set up as the current working directory (the directory Claude was invoked in). Store it as `PROJECT_ROOT`.

---

## Phase 1: Init

Announce to the user:

> Starting Couch Potato setup...

Read `${SETUP_PKG}/references/init-flow.md` and execute it in full. This phase:

1. **Detects orchestration mode** (Agent Teams, parallel subagents, or sequential) by probing available tools.
2. **Runs four parallel scans** of the target project:
   - **Stack Detection** -- language, framework, package manager, monorepo status. Scanners must read `${SETUP_PKG}/references/stacks.md` for detection heuristics.
   - **Project Structure** -- directories, commands, dev port. Scanners must read `${SETUP_PKG}/references/stacks.md` for command defaults.
   - **Claude Code Setup** -- existing .claude/ config, CLAUDE.md quality. Scanners must read `${SETUP_PKG}/references/claude-md-guide.md` for the assessment rubric.
   - **Existing Installation** -- prior Couch Potato or agent files, Codex CLI.
3. **Compiles results** into an adaptation plan.
4. **Presents the plan** to the user for confirmation using numbered options. The user can confirm, change individual items, or abort.

**Manual setup alternative:** If the user requests manual setup or auto-detection fails entirely, skip all scans. Instead, present an empty adaptation plan template for the user to fill in directly. The template contains all plan fields with empty/default values. The user fills each field via the confirmation flow (init-flow.md Section 4). This path is triggered by the manual setup check in init-flow.md Section 0.

Important: when dispatching scan subagents (Mode A or B), each subagent prompt MUST include the absolute path to the reference file it needs. Example for Scan A:

> Read ${SETUP_PKG}/references/stacks.md and follow the heuristics exactly. The target project is at ${PROJECT_ROOT}. [rest of prompt from init-flow.md Scan A]

If the user aborts, stop here. Do not proceed to Phase 2.

Once the user confirms, the adaptation plan is locked. Proceed to Phase 2.

---

## Phase 2: Install

Announce to the user:

> Installing Couch Potato...

Read `${SETUP_PKG}/references/install-flow.md` and execute it in full, passing the locked adaptation plan from Phase 1. This phase:

1. **Pre-install checks** -- verifies write permissions and template accessibility. Templates are at `${SETUP_PKG}/templates/`.
2. **Stages files** to `.couch/.staging/` in the target project, copying from `${SETUP_PKG}/templates/`.
3. **Validates** the staging area against `${SETUP_PKG}/templates/config.schema.json`.
4. **Installs atomically** -- backs up existing files, moves staged files to final locations.
5. **Updates .gitignore** -- adds required entries.
6. **Updates Claude Code settings** -- enables Agent Teams.
7. **Updates CLAUDE.md** -- patches, generates, or skips per user's choice.
8. **Verifies** the installation is complete.
9. **Cleans up** the staging area.

If any step fails, the install flow handles rollback automatically (see install-flow.md Section 10).

---

## Phase 3: Handoff

After Phase 2 completes successfully, present the final message to the user. This is defined in `install-flow.md` Section 11, but summarized here for completeness:

1. Confirm success: **"Couch Potato installed successfully."**
2. List all written and modified files.
3. Explain SOULs: **"SOULs define each agent's cognitive style -- how they think, communicate, and make decisions. You can customize them later via /couch-potato."**
4. Prompt restart: **"Please exit Claude Code and re-enter to pick up the new settings."**

---

## Language Routing

Throughout all phases:
- **User-facing communication**: match the user's language (detect from their messages or system locale).
- **Internal operations**: all file paths, JSON keys, variable names, and log messages remain in English.
- If the user's language is unclear, default to English.

---

## Error Handling

- **Phase 1 failure** (scan errors, tool unavailability): fall back to sequential mode. If scans still fail, report the specific error and abort.
- **Phase 2 failure** (file write errors, validation failures): rollback per install-flow.md Section 10. Report what failed and offer retry or abort.
- **User abort at any point**: stop immediately, write no files, confirm to the user that nothing was changed.
