---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/delete.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Delete command

Remove local branches. Code: `Commands::Delete`. Most guarded command.

## Why this shape

Destructive, so protected names, plan, confirm, a branch snapshot, and a result listing each deleted branch with its SHA (`lib/gitflash/commands/delete.rb:5-7`).

## Shape

- Protected: current, default, `main`, `master`, plus `protected` patterns from [[config]] (`delete.rb:9`, `37-39`). Refusal code `protected_branch` (`delete.rb:49`).
- `-d` unless `--force` then `-D` (`lib/gitflash/repo.rb:76-78`).
- Flow: validate, plan, dry-run, `ui.confirm?`, snapshot, delete each, report (`delete.rb:54-62`).
- Snapshot scope `branches` for the named branches (`delete.rb:59-60`). `undo:` set only when something was deleted (`delete.rb:87`).
- Partial failure gives status `failed`, exit 1, per-branch errors (`delete.rb:79-95`).
- Returns 0 directly when nothing to pick (`delete.rb:16`).

## Connected to

- **joins:** [[repo]], [[change-flow]], [[json-schema]] `delete_*`, [[exit-codes]]
- **looks-like-but-is-not:** `git branch -D` (default is safe `-d`)

## If you change this

- **Hits:** [[json-schema]] `delete_plan` / `delete_result`; the recreate-from-SHA and `undo` contracts agents rely on; [[exit-codes]] (hand-built error hash at `delete.rb:94`).
- **Does not hit:** [[reset]], [[branches]] list logic.

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/delete.rb`
