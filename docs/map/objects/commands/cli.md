---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/cli.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# CLI

Thor entry point. Code: `Cli`, plus `HookCli` for the `hook` subcommand.

## Why this shape

Thin: declares flags and commands, delegates to [[command-runner]]. Heavy logic lives in command classes.

## Shape

- Global flags `--json`, `--yes` / `-y`, `--dry-run` (`lib/gitflash/cli.rb:16-21`).
- Commands via `run_command`: branches, checkout, delete, reset, undo, snapshots, snapshot, gc (`cli.rb:23-79`).
- `hook` subcommand = `HookCli`: `claude`, `install`, `status` (`cli.rb:81-82`; `lib/gitflash/hook_cli.rb`).
- `clean` command (help text in `command_descriptions.yml`).
- `worktree` subcommand (alias `wt`) = `WorktreeCli`, see [[worktree-commands]].
- `schema` (`cli.rb:85`) and `version` (`cli.rb:92`) print outside the envelope.
- `exit_on_failure?` true (`cli.rb:12`). Binary: `bin/gitflash`.

## Connected to

- **owns:** [[command-runner]], all command cards, [[hook-claude]], [[hook-install]]
- **joins:** [[command-descriptions]], [[json-schema]] (`SCHEMA_PATH`, `cli.rb:10`)

## If you change this

- **Hits:** every command's flags and exit path; `spec/lib/gitflash/cli_spec.rb`, `cli_snapshots_spec.rb`.
- **Does not hit:** [[repo]] internals, [[snapshot-store]].
- **Outside-in:** `.claude/settings.local.json` (gitignored globally, this machine) runs `gitflash hook claude` as a PreToolUse hook. Renaming `hook claude` or its output protocol breaks every Claude Code Bash call here silently (the hook always exits 0, `hook_cli.rb:33-35`).

## Surfaces

| Surface | Role |
|---|---|
| shells, agents | invoke |
| Claude Code settings | invoke `hook claude` |

## See

- Source: `lib/gitflash/cli.rb`
