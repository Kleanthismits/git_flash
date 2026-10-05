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

Registers the hooks in Claude Code settings and reports whether they are active. Code: `Hook::Settings`, `Commands::HookInstall`, `Commands::HookStatus`.

## Why this shape

Follows Claude Code's own settings rules so a running session picks the hook up without restart. Install merges into the file and keeps everything else (`lib/gitflash/commands/hook_install.rb`).

## Shape

- Scopes `local` (`.claude/settings.local.json` at the main checkout root, default), `project` (`.claude/settings.json` at the repo top level), `user` (`~/.claude/settings.json`) (`lib/gitflash/hook/settings.rb`, `23-29`).
- Two entries with the same command: `PreToolUse` (snapshots; `--mode` applies) and `PostToolUse` (marks agent branches, see [[hook-marking]]), both matcher `Bash`, timeout 30. Install adds whichever is missing, so running it again upgrades an older install. `Settings#entry(settings, event)` finds one by event.
- Status adds `marking` (per file and overall); the headline says when marking is off.
- Hook entry is found by regex `gitflash hook claude` (`settings.rb`, `52-57`).
- Install: idempotent (`hook_install.rb`), writes pretty JSON, timeout 30 (`hook_install.rb`, `60-66`), `--mode` sets the command (`hook_install.rb`). Invalid JSON raises `invalid_settings` (`settings.rb`).
- Status: lists files per scope, whether installed, and whether `gitflash` is on `PATH` (`lib/gitflash/commands/hook_status.rb`, `34-37`). Works outside a repo (user scope only).
- Uses `Repo#toplevel` and `Repo#main_root` (`lib/gitflash/repo.rb`).

## Connected to

- **owns:** [[hook-claude]] command string
- **joins:** [[repo]], [[command-runner]] (`repo_required:`), [[json-schema]] `hook_install`, `hook_status`
- **looks-like-but-is-not:** gitflash's own settings file `.gitflash.yml` ([[config]]). Install only reads and writes Claude Code settings; hook state is there and in `refs/gitflash/`.

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
