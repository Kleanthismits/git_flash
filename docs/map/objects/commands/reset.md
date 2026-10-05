---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/reset.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Reset command

Move current branch to a commit. Code: `Commands::Reset`.

## Why this shape

Every mode saves a snapshot (branches, HEAD, files) before running, so even soft and mixed resets are undoable. Only `--hard` asks for confirmation, because only it loses work in the working tree (`lib/gitflash/commands/reset.rb:59-66`).

## Shape

- Mode: mixed default, `--soft`, `--hard`; both flags raise `invalid_options` (`reset.rb:27-35`).
- No arg needs a terminal, menu of last 100 commits (`reset.rb:15-19`, `repo.rb:13`).
- Unknown ref raises `unknown_commit` (`reset.rb:39`). Single-commit repo gives `noop` (`reset.rb:68-70`).
- Snapshot reason `gitflash reset --MODE SHA`, scope `branches head worktree`, branch = current (`reset.rb:59-62`).
- Result keeps `previous_commit` and `undo:` (`reset.rb:53-56`).

## Connected to

- **joins:** [[repo]] `reset`, `resolve_commit`; [[commit]]; [[change-flow]]; [[json-schema]] `reset_*`
- **looks-like-but-is-not:** `git reset` (passes `--` and a resolved SHA, `repo.rb:80-82`)

## If you change this

- **Hits:** [[json-schema]] `reset_plan` / `reset_result`; the confirm rule for non-hard modes; snapshot scope.
- **Does not hit:** [[delete]], [[branch]].
- Not covered: plain `git reset` run by an agent directly. That is [[hook-claude]]'s job.

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/reset.rb`
