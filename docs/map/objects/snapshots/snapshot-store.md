---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/snapshots.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the error envelope (#46) and snapshot checks (#48)
---

# Snapshot store

Creates, lists and deletes snapshots. Code: `Snapshots`. Storage is git itself.

## Why this shape

Nothing outside git's object store is written, so snapshots survive without a database, are shared by linked worktrees, and need no new tool (`lib/gitflash/snapshots.rb:10-13`).

## Shape

- One commit per snapshot under `refs/gitflash/snapshots/<id>` (`snapshots.rb:15`, `89`). Message = metadata JSON, tree = empty, parents = every referenced commit so git keeps them (`snapshots.rb:86-91`).
- `create` returns the latest snapshot when state is unchanged (`snapshots.rb:26-32`).
- `list` newest first by `created_at`, skipping unreadable or untrusted refs (`snapshots.rb:38-62`; see below). Ids are `YYYYMMDDTHHMMSSffffff-xxxx` (`snapshots.rb:80-84`).
- `delete` = `update-ref -d`; objects are freed by git's own gc later (`snapshots.rb:68-70`, `lib/gitflash/commands/gc.rb:5-8`).
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

## Damaged refs

`Snapshots#list` reads `%(refname)` with each message; a ref whose message is not a JSON object with a valid `created_at` is skipped with a warning on stderr (`Snapshots#parse`), so one bad ref cannot break every command that lists or takes snapshots.

A snapshot is also skipped when `SnapshotCheck.problem` (`lib/gitflash/snapshot_check.rb`) finds a field it cannot trust: a ref name that is not `REF_PREFIX + id`, a commit id that is not a full hex SHA, a branch name git would refuse (leading `-`, `..`, control characters and the like), or a `worktree_path` that is not absolute. These fields go into git commands and paths in [[restore]] and [[worktree-revival]].

The list is ordered by `created_at` inside each snapshot (then id), not by ref name, so a ref named to sort first cannot become `undo`'s default.
