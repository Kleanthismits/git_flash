---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/snapshots.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Snapshot store

Creates, lists and deletes snapshots. Code: `Snapshots`. Storage is git itself.

## Why this shape

Nothing outside git's object store is written, so snapshots survive without a database, are shared by linked worktrees, and need no new tool (`lib/gitflash/snapshots.rb:10-13`).

## Shape

- One commit per snapshot under `refs/gitflash/snapshots/<id>` (`snapshots.rb:15`, `66`). Message = metadata JSON, tree = empty, parents = every referenced commit so git keeps them (`snapshots.rb:63-68`).
- `create` returns the latest snapshot when state is unchanged (`snapshots.rb:26-32`).
- `list` newest first by ref name (`snapshots.rb:35-39`). Ids are `YYYYMMDDTHHMMSSffffff-xxxx` (`snapshots.rb:57-61`).
- `delete` = `update-ref -d`; objects are freed by git's own gc later (`snapshots.rb:45-47`, `lib/gitflash/commands/gc.rb:5-6`).
- Uses `exec`, so a git failure raises and blocks the change that wanted a snapshot.

## Connected to

- **owns:** [[state-capture]] (`snapshots.rb:21`)
- **owned-by:** `Commands::Base#snapshots` (`lib/gitflash/commands/base.rb`), [[hook-claude]]
- **joins:** [[snapshot]], [[bash-command]]
- **looks-like-but-is-not:** git stash, reflog, `Repo`

## If you change this

- **Hits:** [[change-flow]], [[undo]], [[snapshot-commands]], [[hook-claude]]; the `refs/gitflash/` namespace.
- **Does not hit:** `refs/heads`, reflog, [[repo]].
- **Outside-in:** `refs/gitflash/snapshots/*` in each user repo. Default `git fetch`/`push` skip them; `git gc` keeps them while the ref exists; renaming `REF_PREFIX` orphans every existing snapshot.

## Surfaces

| Surface | Role |
|---|---|
| commands, hooks | create, list, delete |

## See

- Source: `lib/gitflash/snapshots.rb`
