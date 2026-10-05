---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/settings.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Hook install and status

Registers the hook in Claude Code settings and reports whether it is active. Code: `Hook::Settings`, `Commands::HookInstall`, `Commands::HookStatus`.

## Why this shape

Follows Claude Code's own settings rules so a running session picks the hook up without restart. Install merges into the file and keeps everything else (`lib/gitflash/commands/hook_install.rb:7-8`).

## Shape

- Scopes `local` (`.claude/settings.local.json` at the main checkout root, default), `project` (`.claude/settings.json` at the repo top level), `user` (`~/.claude/settings.json`) (`lib/gitflash/hook/settings.rb:15`, `23-29`).
- Hook entry is found by regex `gitflash hook claude` (`settings.rb:16`, `52-57`).
- Install: idempotent (`hook_install.rb:16`), writes pretty JSON, timeout 30 (`hook_install.rb:34-41`, `60-66`), `--mode` sets the command (`hook_install.rb:50-53`). Invalid JSON raises `invalid_settings` (`settings.rb:44-50`).
- Status: lists files per scope, whether installed, and whether `gitflash` is on `PATH` (`lib/gitflash/commands/hook_status.rb:9-16`, `34-37`). Works outside a repo (user scope only).
- Uses `Repo#toplevel` and `Repo#main_root` (`lib/gitflash/repo.rb`).

## Connected to

- **owns:** [[hook-claude]] command string
- **joins:** [[repo]], [[command-runner]] (`repo_required:`), [[json-schema]] `hook_install`, `hook_status`
- **looks-like-but-is-not:** a gitflash config file. gitflash has none; all state is in Claude's settings and `refs/gitflash/`.

## If you change this

- **Hits:** user files outside the repo (`~/.claude/settings.json`, `.claude/settings*.json`); [[json-schema]] hook defs; `PATTERN` must keep matching what install writes.
- **Does not hit:** [[snapshot-store]], [[hook-rules]].
- **Outside-in:** reads and writes Claude Code settings files. A change in Claude's settings layout breaks install and status.

## Surfaces

| Surface | Role |
|---|---|
| humans, agents | run install/status |
| Claude Code | reads the written settings |

## See

- Source: `lib/gitflash/hook/settings.rb`, `lib/gitflash/commands/hook_install.rb`, `lib/gitflash/commands/hook_status.rb`
