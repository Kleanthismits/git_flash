---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/claude.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the fixes for #34, #35, #37 and #41
---

# Claude hook

Claude Code hook for the Bash tool, for two events. Command: `gitflash hook claude`. Code: `HookCli#claude` and `Hook::Claude`. Roadmap standard 2: protection for commands agents run themselves.

## Why this shape

The agent keeps using plain git. The hook snapshots first and tells the agent how to undo. In snapshot mode it must never block a command by accident, so errors are swallowed. In `ask` and `deny` mode the user chose protection, so an error asks or blocks instead of letting the command through (`Hook::Failure`).

## Shape

- Event: `hook_event_name == 'PostToolUse'` goes to [[hook-marking]] (marks branches the command created, `additionalContext` tells the agent); anything else, including input without an event name, is the PreToolUse path below. The same command string is registered under both events, so existing installs keep working.
- Run by Claude Code, not by people: the command is `hide: true` in `HookCli` (missing from `gitflash hook` help; `gitflash hook help claude` still works) and, when stdin is a terminal, prints `TERMINAL_NOTE` and returns instead of waiting for input. Piped input, as Claude Code sends, is unchanged. Specs that feed it input stub `$stdin.tty?` false so they pass in a terminal too.
- Input: hook JSON on stdin. Only `tool_name == 'Bash'` is looked at (`lib/gitflash/hook/claude.rb`).
- In `ask` mode a risky command is asked about even when no snapshot could be saved (not in a git work tree); the note then says nothing can be undone (`Hook::Messages.unsaved`). Texts for Claude live in `Hook::Messages`; with several directories it lists one `gitflash undo ID` per snapshot, each with the directory to run it in. A failure while recording branches (`record_branches`) is warned about and never stops the snapshot or the decision.
- Modes (`claude.rb`): `snapshot` (default; save, allow), `ask` (save, ask user), `deny` (block, point to gitflash command) (`claude.rb`, `71-92`).
- One snapshot per directory, merged across commands there (`CommandParser::Target.merge`); reason `agent hook: before ...` (`claude.rb`).
- What no snapshot can bring back is named to the agent by `Hook::Losses` (`lib/gitflash/hook/losses.rb`): the ignored files a target with `ignored` deletes (`git clean -x/-X`, `git worktree remove`; read with `git ls-files --others --ignored --exclude-standard --directory`, first five shown) and a snapshot's `skipped_files` (untracked files over 50 MB). The undo advice no longer implies these come back. Snapshot mode still does not ask about them.
- A target without branch names (`xargs git branch -D < list`, `git update-ref -d` with no `refs/heads/` argument) saves every branch (`branches` returns nil), not none.
- The `:current` branch is read from the full ref with `refs/heads/` removed (`claude.rb`), so a tag named like the branch cannot change the name saved.
- Output is Claude Code's hook protocol (`hookSpecificOutput`, `additionalContext`, `permissionDecision`), not gitflash's envelope (`claude.rb`).
- `HookCli#claude` rescues `StandardError`, warns and exits 0 (`lib/gitflash/hook_cli.rb`). The output then comes from `Hook::Failure.output` (`lib/gitflash/hook/failure.rb`): nothing in snapshot mode or for PostToolUse input, otherwise `permissionDecision` `ask` / `deny` with `Messages.failure`. If that output cannot be written either (stdin or stdout fails), ask and deny mode exit 2, which Claude Code reads as a block; snapshot mode still exits 0. It does not use [[command-runner]] or [[ui-output]].
- A snapshot that raises (unreadable file, `index.lock`, bad snapshot ref) is warned about in `save` and counts as unsaved, so `ask` still asks.
- Paths are read by `Hook::Paths` (see [[hook-rules]]): `~unknownuser` never raises, and a shell-decided `cd` / `-C` path falls back to the hook's `cwd` as a `Paths::Guessed` directory. Targets from such a directory carry `guessed`, and the output adds `Messages.guessed`: the snapshot was taken where Claude runs and may not cover the repository the command changes.
- Every risky command that runs where no snapshot could be saved is named to the agent with `Messages.unsaved` (with the directory), in every mode and next to the `gitflash undo` advice for the ones that were saved. Before, snapshot mode stayed silent.

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

- Source: `lib/gitflash/hook/claude.rb`, `lib/gitflash/hook/failure.rb`, `lib/gitflash/hook_cli.rb`
