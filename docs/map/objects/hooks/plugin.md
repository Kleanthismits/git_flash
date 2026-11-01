---
type: object
cluster: hooks
universe: live
status: verified
entity: .claude-plugin/plugin.json
verified_on: 2026-10-31
verified_at: cb4cd75 plus the plugin (phase 4)
---

# Claude Code plugin

The repository root is a Claude Code plugin and its own marketplace. Files: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`. No Ruby code.

## Why this shape

One install gives a Claude Code user the [[hook-claude]] hook, the [[mcp]] server and the [[skill]]. Components are declared inline in `plugin.json` (`mcpServers`, `hooks`, `skills: ./skills/`), so the repository root has no `.mcp.json` or `hooks/` that Claude Code would also read as this project's own config.

## Shape

- `plugin.json`: `name` gitflash, `version` = `Gitflash::VERSION`, `skills` `./skills/` (the gem's `skills/gitflash/SKILL.md`), `mcpServers.gitflash` = `gitflash mcp`, `hooks` PreToolUse and PostToolUse with matcher `Bash`, command `gitflash hook claude`, timeout 30: the same entries [[hook-install]] writes in snapshot mode.
- `marketplace.json`: marketplace `gitflash`, one plugin, `source` `./`.
- Commands run by name from `PATH`: the plugin does nothing without the gem, and needs a gem with `mcp` (0.8.0 or newer).
- `spec/plugin_spec.rb` checks the version, the hook entries against `HookInstall::MARKING_COMMAND` and `Settings::PATTERN`, the MCP command and that the skill path is the gem's skill. `claude plugin validate .` passes with warnings (no icon, `CLAUDE.md` at the root is not plugin context).
- Not seen by `hook status` ([[hook-install]] reads settings files only). With `hook install` too, the hook runs twice.

## Connected to

- **joins:** [[hook-claude]], [[hook-install]] (same entries), [[mcp]], [[skill]], [[cli]] (`version`)
- **looks-like-but-is-not:** `.claude/settings*.json` written by [[hook-install]]. The plugin's hooks live in Claude Code's plugin store, not in a settings file.

## If you change this

- **Hits:** `Gitflash::VERSION` bumps (spec fails until `plugin.json` matches); renaming `hook claude`, `mcp` or the skill path; Claude Code's plugin manifest format.
- **Does not hit:** anything in `lib/` at runtime.
- **Outside-in:** users install from the GitHub default branch. A manifest on `main` that names a command the released gem lacks fails for them.

## Surfaces

| Surface | Role |
|---|---|
| Claude Code | reads the manifest, runs the hook and the server, loads the skill |
| users | `/plugin marketplace add`, `/plugin install` |

## See

- Source: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `spec/plugin_spec.rb`
