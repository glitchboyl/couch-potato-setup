# Plugin Migration Design

**Type**: Architecture Decision Record (ADR)
**Status**: Proposed
**Version context**: Couch Potato v3.1.0 → v3.2.0
**Purpose**: Capture the full plugin refactor decision so req-004 can execute without redoing any research.

---

## 1. Problem Statement

The user wants a `/couch-potato:update` slash command. Colon-subcommand syntax (`/couch-potato:update`) is only available in Claude Code **plugin format** — it is not supported for standard skills or commands. The current setup is a plain skill (`templates/skill/SKILL.md`) invoked via `/couch-potato`, not a plugin. Therefore, shipping `/couch-potato:update` requires first converting to plugin format.

Without this conversion, there is no supported mechanism for multi-subcommand invocation under a single namespace (e.g., `/couch-potato:init`, `/couch-potato:update`).

---

## 2. Decision

Refactor the Couch Potato setup package to Claude Code plugin format.

The current flat-skill layout (`templates/skill/SKILL.md` as entrypoint) will be replaced by a `plugin.json`-anchored plugin structure with discrete skills for `init` and `update`, a `SessionStart` hook for version notification, and a `${CLAUDE_PLUGIN_DATA}` strategy for user-customizable artifacts (SOULs, config).

### Sub-decision: Dual workflow architecture

Ship two parallel workflow definitions — **team-mode** and **multi-agent-mode** — and select which to install at init time based on the user's environment, not at runtime.

- **Team-mode workflow**: uses Claude Code's native agent-teams feature (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, requires v2.1.32+). Agents communicate directly peer-to-peer; Team Lead coordinates via the built-in team mechanism.
- **Multi-agent-mode workflow**: hub-and-spoke coordination where the main Claude instance (Team Lead) is the sole orchestrator. All agent-to-agent discussion is relayed through main. No experimental flag required; works on any Claude Code version.

The init skill detects whether the environment satisfies agent-team requirements (Claude Code v2.1.32+ and the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` flag) and installs exactly one workflow. The installed mode is recorded in `.couch/config.json` so the update skill can later detect drift (e.g., user upgraded Claude Code) and offer a mode upgrade.

---

## 3. Rationale

Four Researcher findings inform this decision:

1. **Subcommand syntax requirement**: Colon-subcommand syntax (`/pluginName:subcommand`) is only available in plugin format. Standard skill files do not support multi-subcommand invocation. Converting to plugin format is the only path to shipping `/couch-potato:init` and `/couch-potato:update` as distinct, namespaced commands.

2. **SessionStart hook auto-notification**: Plugin format supports a `SessionStart` hook in `plugin.json` that runs a script at session start. This enables automatic GitHub version check and user notification without any user action — the user simply sees a message if a newer version is available when they open Claude Code.

3. **File write compatibility**: The init skill writes files to arbitrary project paths. Plugin format does not restrict what paths skills can write to — `${CLAUDE_PLUGIN_DATA}` is for plugin-private state, but skills can still write to project directories. Init-time customization is fully compatible with plugin format; no behavioral changes to the init flow are required.

4. **Hook compatibility**: `PreToolUse` hooks defined in a skill's SKILL.md frontmatter work the same way in plugin format as in standalone skill format. The existing `restrict_write_path.sh` hook requires no changes to its logic — only its location in the plugin directory tree changes.

**Why dual-workflow over runtime detection**: Two parallel workflows are each internally self-consistent — there is no runtime overhead from checking environment state on every invocation, no risk of mid-session degradation if the env flag disappears, and no surprising behavior changes in long sessions. The update skill can also detect environment drift (user upgraded Claude Code since initial install) and offer a one-time mode-switch prompt, which is the correct time to present that choice. The honest tradeoff is doubled maintenance burden: every workflow change must be applied in both `team-mode` and `multi-agent-mode`. The alternatives are worse: requiring all users to enable an experimental flag before installation excludes users who cannot or will not do so; building a hub-and-spoke runtime fallback inside the team-mode workflow adds permanent complexity that benefits a minority case. Keeping the workflows separate and minimal (multi-agent-mode is deliberately a degraded but complete experience, not a feature-match of team-mode) keeps the maintenance cost bounded.

---

## 4. Target Plugin Layout

The plugin root is the directory registered with Claude Code (name: `couch-potato`). Concrete directory tree:

```
.claude-plugin/
  plugin.json                        # plugin manifest: name, version, skills, hooks
  VERSION                            # version file (same content as repo root VERSION)
  CHANGELOG.md                       # changelog (same as repo root)
  skills/
    init/
      SKILL.md                       # init skill (replaces current setup.md entry point)
    update/
      SKILL.md                       # update skill (new — reads config version, fetches changelog)
  hooks/
    hooks.json                       # hook definitions
    session-start.sh                 # SessionStart version check script
    restrict_write_path.sh           # existing PreToolUse hook (moved from templates/skill/hooks/)
  agents/                            # agent definitions (shared across both modes)
  references/
    team-mode/
      workflow.md                    # team-mode workflow (uses native agent-team coordination)
      protocol.md                    # team-mode protocol
      SKILL-body.md                  # Team Lead SKILL.md body for team-mode
      souls/                         # Team Lead SOUL differs between modes; others may be shared
    multi-agent-mode/
      workflow.md                    # multi-agent workflow (hub-and-spoke; main relays all discussion)
      protocol.md                    # multi-agent protocol
      SKILL-body.md                  # Team Lead SKILL.md body for multi-agent-mode
      souls/                         # Team Lead SOUL for multi-agent-mode
    schemas.md                       # shared across both modes
```

`plugin.json` registers:
- `skills/init/SKILL.md` as the `init` subcommand
- `skills/update/SKILL.md` as the `update` subcommand
- `hooks/session-start.sh` under `hooks.SessionStart`

---

## 5. SOUL Persistence Strategy

SOULs must be user-customizable but also shippable as defaults. The plugin format `${CLAUDE_PLUGIN_DATA}` variable provides a per-installation writable directory that plugin updates do not overwrite.

Strategy:

- **Default souls** live at `${CLAUDE_PLUGIN_ROOT}/souls/` — read-only, ships with the plugin, updated on plugin upgrade.
- **On first `/couch-potato:init`**, the init skill copies souls from `${CLAUDE_PLUGIN_ROOT}/souls/` to `${CLAUDE_PLUGIN_DATA}/souls/` — this creates the user's editable copy.
- **The generated SKILL.md** (installed to the target project) references `${CLAUDE_PLUGIN_DATA}/souls/` with a fallback to `${CLAUDE_PLUGIN_ROOT}/souls/` if the data dir copy does not exist.
- **Users customize** by editing files in `${CLAUDE_PLUGIN_DATA}/souls/`. Plugin upgrades only update `${CLAUDE_PLUGIN_ROOT}/souls/` — the data-dir copies are never overwritten.

This pattern means: fresh installs always get up-to-date default souls; users who have customized retain their changes across upgrades.

---

## 6. SessionStart Hook Design

The hook is registered in `plugin.json` under `hooks.SessionStart` and points to `hooks/session-start.sh`. It checks GitHub for a newer version and prints a one-line notification if one is found. On network failure it exits silently.

Full draft script (`hooks/session-start.sh`):

```sh
#!/bin/sh
# session-start.sh — runs at Claude Code session start
# Checks if a newer version of Couch Potato is available on GitHub.

LOCAL_VERSION_FILE="${CLAUDE_PLUGIN_ROOT}/VERSION"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/glitchboyl/couch-potato-setup/main/VERSION"

# Read local version
if [ ! -f "$LOCAL_VERSION_FILE" ]; then
  exit 0
fi
LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE" | tr -d '[:space:]')

# Fetch remote version (fail silently — no network = no notification)
REMOTE_VERSION=$(curl -sf --max-time 3 "$REMOTE_VERSION_URL" 2>/dev/null | tr -d '[:space:]')
if [ -z "$REMOTE_VERSION" ]; then
  exit 0
fi

# Compare (simple string compare works for semver X.Y.Z if zero-padded or same length)
# For robust comparison, use sort -V if available
if command -v sort > /dev/null 2>&1; then
  LATEST=$(printf '%s\n%s' "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | tail -n1)
else
  LATEST="$REMOTE_VERSION"
fi

if [ "$LATEST" != "$LOCAL_VERSION" ]; then
  echo "Couch Potato update available: $LOCAL_VERSION -> $REMOTE_VERSION"
  echo "Run /couch-potato:update to upgrade."
fi
```

The hook must be marked executable (`chmod +x hooks/session-start.sh`) and registered in `plugin.json` under `hooks.SessionStart`.

---

## 7. Update Skill Design

The `skills/update/SKILL.md` skill implements the following flow when the user runs `/couch-potato:update`. See section 9 (Update Flow Logic) for mode-aware branching.

1. **Read installed version**: reads `.couch/config.json` for the `version` field.
2. **Fetch remote changelog**: fetches `https://raw.githubusercontent.com/glitchboyl/couch-potato-setup/main/CHANGELOG.md` from GitHub raw.
3. **Parse changelog delta**: extracts all version entries newer than the installed version (by semver comparison). If the installed version is not found in CHANGELOG.md, treat it as very old and show the full changelog.
4. **Present delta**: shows the parsed changelog entries to the user for review before making any changes.
5. **Classify files**: for each file to update, classifies as verbatim or customizable per the table in section 10.
6. **Apply updates**:
   - **Verbatim files**: written automatically with no user prompt.
   - **Customizable files**: shows a diff and prompts the user per file: `[Y] overwrite / [N] keep mine / [D] show diff`.
7. **Update version**: writes the new version string to the `version` field in `.couch/config.json` after all files are successfully processed.
8. **Remind restart**: prints a reminder to restart Claude Code so the updated plugin takes effect.

---

## 8. Init Flow Logic

When the user runs `/couch-potato:init`, the skill first checks for a `.couch/setup-state.json` file. If it exists, the install was interrupted (user upgraded Claude Code and restarted) — skip to the resume path below.

Otherwise, the skill executes one of three cases based on environment detection:

### Case A — Claude Code v2.1.32+ AND `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set

Install team-mode workflow directly. Done.

### Case B — Claude Code v2.1.32+ AND flag NOT set

Prompt the user:

> "Your Claude Code supports agent teams but the experimental flag isn't enabled. May I add `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to your `.claude/settings.json`? (No restart needed.)"

- **If yes**: write the flag to `.claude/settings.json` → install team-mode workflow → done.
- **If no**: install multi-agent-mode workflow → done.

### Case C — Claude Code version < 2.1.32

Detect the install method via `which claude` path heuristic:

| Path pattern | Install method |
|---|---|
| `~/.local/bin/claude` | Native (direct install) |
| `/opt/homebrew/bin/claude` or `/usr/local/bin/claude` (brew-managed) | Homebrew |
| Contains `npm` or `node_modules` in path | npm (deprecated) |
| WinGet-managed path on Windows | WinGet |
| Unknown | Prompt user to identify |

Prompt the user:

> "Agent team mode requires Claude Code v2.1.32+. You have v{X}. Want to upgrade? (After upgrade you must restart Claude Code and re-run `/couch-potato:init` — I'll resume where we left off.)"

- **If yes**:
  1. Save partial install state to `.couch/setup-state.json` (schema: `{ "phase": "pre-install", "detected_at": "<ISO>" }`).
  2. Print the exact upgrade command for the detected method:
     - **Native**: `claude update`
     - **Homebrew**: `brew upgrade claude-code`
     - **WinGet**: `winget upgrade Anthropic.ClaudeCode`
     - **npm**: `npm update -g @anthropic-ai/claude-code` — also suggest migrating to native (`curl -fsSL https://claude.ai/install.sh | bash`) since npm is the deprecated install path.
     - **Unknown**: list all options, let user pick.
  3. Tell user: "Run that command, restart Claude Code, then re-run `/couch-potato:init` — I'll resume."
  4. Skill exits this session.
- **If no**: install multi-agent-mode workflow → done.

### Resume path (after restart)

On re-run, init detects `.couch/setup-state.json`. It re-detects the current Claude Code version and flag state, then proceeds directly to mode selection (Cases A/B/C above) and continues installation from the beginning of the install phase — `setup-state.json` is deleted after successful completion.

---

## 9. Update Flow Logic

When the user runs `/couch-potato:update`:

1. **Read `.couch/config.json`** to determine installed mode (`team-mode` or `multi-agent-mode`) and installed version.

**Case A — installed mode is `team-mode`**

Run normal update logic: fetch remote CHANGELOG, parse delta, classify files, apply updates (verbatim auto-write, customizable prompt-per-file), update version in config, remind restart.

**Case B — installed mode is `multi-agent-mode`**

Re-check current environment (Claude Code version + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag).

- **If the environment now satisfies team-mode requirements**:
  Prompt the user once:
  > "You're running the multi-agent-mode workflow. Your Claude Code now supports agent teams. Want to switch to team-mode for better coordination? (Replaces `workflow.md`, `protocol.md`, and `SKILL.md` body with team-mode versions.)"
  - **If yes**: install team-mode workflow files, overwriting the multi-agent-mode files → then run normal update logic for the newly installed team-mode files → update `mode` in config to `team-mode`.
  - **If no**: run normal update logic for multi-agent-mode files only.

- **If the environment still does not satisfy team-mode requirements**: skip the prompt entirely (do not repeat it on every update run) → run normal update logic for multi-agent-mode files.

---

## 10. File Classification Table

Workflow files (`workflow.md`, `protocol.md`, `SKILL-body.md`, mode-specific `souls/`) exist in both mode directories. Within a given mode they are treated as verbatim — the update skill overwrites them automatically. The *choice* of mode is per-install and is not changed during a normal update (only surfaced as an opt-in prompt per section 9).

| Verbatim — safe to overwrite | Customizable — prompt user | Mode scope |
|---|---|---|
| `references/team-mode/workflow.md` | | team-mode installs |
| `references/team-mode/protocol.md` | | team-mode installs |
| `references/team-mode/SKILL-body.md` | | team-mode installs |
| `references/team-mode/souls/*.md` | | team-mode installs |
| `references/multi-agent-mode/workflow.md` | | multi-agent installs |
| `references/multi-agent-mode/protocol.md` | | multi-agent installs |
| `references/multi-agent-mode/SKILL-body.md` | | multi-agent installs |
| `references/multi-agent-mode/souls/*.md` | | multi-agent installs |
| `references/schemas.md` | | both modes |
| `hooks/restrict_write_path.sh` | | both modes |
| `templates/config.schema.json` | | both modes |
| `agents/architect.md` (base template) | | both modes |
| `agents/researcher.md` | | both modes |
| `agents/coder.md` | | both modes |
| `agents/tester.md` | | both modes |
| `agents/retrospective.md` | | both modes |
| | `.claude/skills/couch-potato/SKILL.md` (users may customize Team Lead) | both modes |
| | `.couch/config.json` (user project config) | both modes |
| | `installed souls/*.md` (SOULs are user-customizable) | both modes |
| | `.claude/agents/*.md` (users may add/modify agents) | both modes |
| | `CLAUDE.md` (user project docs) | both modes |

Note: in plugin format, verbatim files live under `${CLAUDE_PLUGIN_ROOT}/` (updated automatically on plugin upgrade), customizable copies live under `${CLAUDE_PLUGIN_DATA}/` (user-owned, never overwritten by plugin updates).

---

## 11. Migration Steps for req-004

Ordered task breakdown for the Architect / Coder executing req-004:

1. Create `plugin.json` manifest at plugin root with: name (`couch-potato`), version, skill registrations for `init` (`skills/init/SKILL.md`) and `update` (`skills/update/SKILL.md`), and `SessionStart` hook reference (`hooks/session-start.sh`).
2. Move `setup.md` logic into `skills/init/SKILL.md` (init skill) — adapt all path references from relative `SETUP_PKG`-style to `${CLAUDE_PLUGIN_ROOT}`.
3. Implement init skill mode detection logic: version detection, flag check, three-case branching (Cases A/B/C per section 8).
4. Implement init skill upgrade prompt and `setup-state.json` resume pattern (Case C in section 8).
5. Write `skills/update/SKILL.md` (update skill) implementing the update flow described in section 7 and mode-aware branching in section 9.
6. Implement update skill mode awareness and mode-switch conversion prompt (Case B in section 9).
7. Write `hooks/session-start.sh` using the draft in section 6; finalize and verify in req-004.
8. Move `templates/skill/hooks/restrict_write_path.sh` to `hooks/restrict_write_path.sh` in the plugin structure; update frontmatter references in any SKILL.md that registers it.
9. Design team-mode `workflow.md` and `protocol.md` (adapt existing references for plugin format and `${CLAUDE_PLUGIN_ROOT}` paths).
10. Design multi-agent-mode `workflow.md` and `protocol.md` — hub-and-spoke coordination, main relays all agent-to-agent discussion. Document limitations clearly (no peer-to-peer agent discussion).
11. Design multi-agent-mode `SKILL-body.md` — Team Lead role description differs: main is the only orchestrator.
12. Decide which SOULs differ between modes. Team Lead SOUL likely needs a multi-agent variant; architect, researcher, coder, tester, retrospective SOULs may be reusable across modes. Document the decision.
13. Move agent definitions to `agents/` at plugin root; confirm they are mode-agnostic or split as needed.
14. Move shared references (schemas) to plugin `references/` directory; update all inbound links.
15. Update install-flow documentation: target paths change from `templates/skill/...` to `${CLAUDE_PLUGIN_ROOT}/...`.
16. Test init flow end-to-end in a scratch project — all three cases (A, B, C including resume-after-restart).
17. Test update flow with a synthetic version bump; test mode-switch prompt (Case B in section 9).
18. Update README.md install instructions for plugin format (include plugin registration command; confirm exact CLI command first — see Open Questions). Document multi-agent-mode limitations prominently.
19. Tag v3.2.0.

---

## 12. Open Questions / Risks for req-004

- **Plugin registration UX**: how does the user register the plugin with Claude Code? Confirm the exact CLI command (e.g., `claude plugin add <path>`) before writing README install instructions. This is a blocking unknown for step 18 of the migration.

- **`${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` availability in skill context**: these env vars must be available inside skill execution context, not just in hook scripts. If they are not injected into skill execution, the init skill needs an alternative path strategy for locating default souls and reference files.

- **SessionStart hook latency**: the version check runs at every session start. `curl -sf --max-time 3` should fail silently on network unavailability, but the 3-second timeout could add perceived latency if DNS resolution hangs. Verify behavior with a firewalled test before shipping.

- **CHANGELOG.md parsing robustness**: the update skill parses CHANGELOG.md by semver heading (`## [X.Y.Z]`). The parser must handle: (a) installed version not present in changelog (show full history), (b) malformed headings, (c) future changelog format changes. Define the parsing contract explicitly in the update skill spec.

- **Customizable soul files during update**: if the user has customized a soul file in `${CLAUDE_PLUGIN_DATA}/souls/`, the update skill must not overwrite it. The data-dir strategy handles this for plugin-format installs, but the update skill must check whether data-dir copies exist before deciding to update root copies. The logic branch needs explicit specification.

- **Backward compatibility — skill to plugin migration**: users who installed v3.1.0 (skill format) will need a migration path to v3.2.0 (plugin format). The existing `.claude/skills/couch-potato/` install is incompatible with plugin format. The update skill can detect skill-format installs and guide migration, but this is non-trivial and may require a one-time manual step or a dedicated migration script.

- **Maintenance burden of dual workflows**: every workflow change must be applied in both `team-mode` and `multi-agent-mode` references. Mitigation: keep multi-agent-mode scope minimal — do not try to feature-match team mode. Accept it as a deliberately degraded but complete experience.

- **Multi-agent workflow UX limitations**: main must relay all agent-to-agent discussion, which increases latency and context usage compared to team mode. This must be documented prominently in the README and surfaced to the user at install time (Case B/C in init flow) so they understand what they are getting.

- **Resume-after-restart pattern**: the `setup-state.json` schema needs explicit design. At minimum it must persist: project path, detected stack, partially completed config values, and the step at which init was interrupted. What state must survive the restart boundary vs. what can be re-detected needs to be specified before implementation.

---

## 13. Sources

- [Claude Code Plugin Documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) — plugin format spec, `plugin.json` schema, subcommand syntax, `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}` variables. **Verify URL before use in req-004 — use canonical Anthropic docs domain.**
- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) — `SessionStart` hook registration, `PreToolUse` hook behavior, hook script execution context. **Verify URL before use in req-004.**
- [Claude Code Agent Teams Documentation](https://docs.anthropic.com/en/docs/claude-code/agent-teams) — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag, minimum version requirement (v2.1.32), team coordination behavior. **Verify URL before use in req-004.**
- [Claude Code Setup / Install Documentation](https://docs.anthropic.com/en/docs/claude-code/setup) — install methods (native, Homebrew, npm, WinGet), `claude update` command, npm deprecation notice. **Verify URL before use in req-004.**
- [GitHub Issue #32732](https://github.com/anthropics/claude-code/issues/32732) — model inheritance hazard referenced in req-002 context (Opus inheritance in subagents).
- [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/) — changelog format used by CHANGELOG.md.
- [Semantic Versioning](https://semver.org/) — versioning scheme used by VERSION file and release tags.
