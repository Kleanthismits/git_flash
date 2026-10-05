---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/claude.rb
verified_on: 2026-10-04
verified_at: 36940dc plus the tag-safe ref fix
---

# Claude hook

Claude Code hook for the Bash tool, for two events. Command: `gitflash hook claude`. Code: `HookCli#claude` and `Hook::Claude`. Roadmap standard 2: protection for commands agents run themselves.

## Why this shape

The agent keeps using plain git. The hook snapshots first and tells the agent how to undo. It must never block a command by accident, so every error is swallowed.

## Shape

- Event: `hook_event_name == 'PostToolUse'` goes to [[hook-marking]] (marks branches the command created, `additionalContext` tells the agent); anything else, including input without an event name, is the PreToolUse path below. The same command string is registered under both events, so existing installs keep working.
- Input: hook JSON on stdin. Only `tool_name == 'Bash'` is looked at (`lib/gitflash/hook/claude.rb`).
- Modes (`claude.rb`): `snapshot` (default; save, allow), `ask` (save, ask user), `deny` (block, point to gitflash command) (`claude.rb`, `71-92`).
- One snapshot per directory, merged across commands there (`claude.rb`); reason `agent hook: before ...` (`claude.rb`).
- The `:current` branch is read from the full ref with `refs/heads/` removed (`claude.rb`), so a tag named like the branch cannot change the name saved.
- Output is Claude Code's hook protocol (`hookSpecificOutput`, `additionalContext`, `permissionDecision`), not gitflash's envelope (`claude.rb`).
- `HookCli#claude` rescues `StandardError`, warns, exits 0 (`lib/gitflash/hook_cli.rb`). It does not use [[command-runner]] or [[ui-output]].

## Connected to

- **owns:** [[hook-rules]] (what to save), [[snapshot-store]] (where), [[hook-marking]] (what to mark)
- **owned-by:** [[cli]] (`hook` subcommand)
- **joins:** [[hook-install]] registers it; [[undo]] is the revert it advertises
- **looks-like-but-is-not:** `gitflash reset` / `delete`, which snapshot through [[change-flow]]. The hook covers plain `git`.

## If you change this

- **Hits:** every Claude Code Bash call where the hook is installed; the `gitflash undo ID` advice string; [[hook-install]] (`PATTERN` matches `gitflash hook claude`, `settings.rb`).
- **Hits (post):** `hook_event_name` handling in `Hook::Claude#call`; a PostToolUse input must never reach the snapshot path.
- **Does not hit:** [[json-schema]] (`hook claude` is not in the `command` enum), [[exit-codes]].
- **Outside-in:** Claude Code's hook input/output protocol; `.claude/settings*.json` entries. A protocol change on Claude's side breaks this with no error (exit 0).

## Surfaces

| Surface | Role |
|---|---|
| Claude Code | calls, reads stdout JSON |
| agent | reads `additionalContext` |

## See

- Source: `lib/gitflash/hook/claude.rb`, `lib/gitflash/hook_cli.rb`
