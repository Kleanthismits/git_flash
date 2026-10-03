---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/snapshot_create.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Snapshot commands

Three small commands over the store: `snapshot`, `snapshots`, `gc`. Code: `SnapshotCreate`, `SnapshotList`, `Gc`.

## Why this shape

Give agents an explicit save point before a risky step (`snapshot`), a way to find ids (`snapshots`), and a way to prune (`gc`).

## Shape

- `snapshot`: `--message`, `--scope branches head worktree stashes` (default all); bad scope raises `invalid_options` (`lib/gitflash/commands/snapshot_create.rb:7-20`). Result `{ snapshot }` and `undo:` (`snapshot_create.rb:9`).
- `snapshots`: read-only list, newest first (`lib/gitflash/commands/snapshot_list.rb:7-11`).
- `gc --older-than DAYS` (default 30): plan, dry-run, confirm, delete refs (`lib/gitflash/commands/gc.rb:8-28`). Age uses `Time.now` (`gc.rb:30-33`). Objects are freed by git's gc later.
- Option definitions: `lib/gitflash/cli.rb:60-79`.

## Connected to

- **joins:** [[snapshot-store]], [[snapshot]], [[json-schema]] (`snapshot_result`, `snapshots_result`, `gc_*`), [[change-flow]]
- **looks-like-but-is-not:** `git gc`; `gitflash gc` only deletes snapshot refs

## If you change this

- **Hits:** [[json-schema]] defs above; retention: nothing deletes snapshots except `gc`, so the store grows until it runs.
- **Does not hit:** [[undo]], [[hook-claude]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write and read |

## See

- Source: `lib/gitflash/commands/snapshot_create.rb`, `snapshot_list.rb`, `gc.rb`
