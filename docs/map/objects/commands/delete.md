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

Destructive, so protected names, plan, confirm, a branch snapshot, and a result listing each deleted branch with its SHA (`lib/gitflash/commands/delete.rb`).

## Shape

- Protected: current, default, `main`, `master`, `protected` patterns from [[config]], branches checked out in a worktree: rule in `Protection` ([[cleanup]]) (`delete.rb`, `37-39`). Refusal code `protected_branch` (`delete.rb`).
- `-d` unless `--force` then `-D` (`lib/gitflash/repo.rb`).
- Flow: validate, plan, dry-run, `ui.confirm?`, snapshot, delete each, report (`delete.rb`).
- Snapshot scope `branches` for the named branches (`delete.rb`). `undo:` set only when something was deleted (`delete.rb`).
- Partial failure gives status `failed`, exit 1, per-branch errors (`delete.rb`).
- Returns 0 directly when nothing to pick (`delete.rb`).

## Connected to

- **owned-by:** [[clean]] (subclass; hook `build_plan`)
- **joins:** [[repo]], [[change-flow]], [[json-schema]] `delete_*`, [[exit-codes]]
- **looks-like-but-is-not:** `git branch -D` (default is safe `-d`)

## If you change this

- **Hits:** [[json-schema]] `delete_plan` / `delete_result`; the recreate-from-SHA and `undo` contracts agents rely on; [[exit-codes]] (hand-built error hash at `delete.rb`).
- **Does not hit:** [[reset]], [[branches]] list logic.

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/delete.rb`
