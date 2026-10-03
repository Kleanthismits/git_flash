---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/claude.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Claude hook

Claude Code PreToolUse hook for the Bash tool. Command: `gitflash hook claude`. Code: `HookCli#claude` and `Hook::Claude`. Roadmap standard 2: protection for commands agents run themselves.

## Why this shape

The agent keeps using plain git. The hook snapshots first and tells the agent how to undo. It must never block a command by accident, so every error is swallowed.

## Shape

- Input: hook JSON on stdin. Only `tool_name == 'Bash'` is looked at (`lib/gitflash/hook/claude.rb:35-40`).
- Modes (`claude.rb:16`): `snapshot` (default; save, allow), `ask` (save, ask user), `deny` (block, point to gitflash command) (`claude.rb:24-31`, `71-92`).
- One snapshot per directory, merged across commands there (`claude.rb:43-50`); reason `agent hook: before ...` (`claude.rb:59`).
- Output is Claude Code's hook protocol (`hookSpecificOutput`, `additionalContext`, `permissionDecision`), not gitflash's envelope (`claude.rb:71-92`).
- `HookCli#claude` rescues `StandardError`, warns, exits 0 (`lib/gitflash/hook_cli.rb:30-35`). It does not use [[command-runner]] or [[ui-output]].

## Connected to

- **owns:** [[hook-rules]] (what to save), [[snapshot-store]] (where)
- **owned-by:** [[cli]] (`hook` subcommand)
- **joins:** [[hook-install]] registers it; [[undo]] is the revert it advertises
- **looks-like-but-is-not:** `gitflash reset` / `delete`, which snapshot through [[change-flow]]. The hook covers plain `git`.

## If you change this

- **Hits:** every Claude Code Bash call where the hook is installed; the `gitflash undo ID` advice string; [[hook-install]] (`PATTERN` matches `gitflash hook claude`, `settings.rb:16`).
- **Does not hit:** [[json-schema]] (`hook claude` is not in the `command` enum), [[exit-codes]].
- **Outside-in:** Claude Code's hook input/output protocol; `.claude/settings*.json` entries. A protocol change on Claude's side breaks this with no error (exit 0).

## Surfaces

| Surface | Role |
|---|---|
| Claude Code | calls, reads stdout JSON |
| agent | reads `additionalContext` |

## See

- Source: `lib/gitflash/hook/claude.rb`, `lib/gitflash/hook_cli.rb`
