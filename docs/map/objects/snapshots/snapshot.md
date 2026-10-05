---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/snapshot.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Snapshot

Saved repository state that `gitflash undo` restores. Code: `Snapshot = Data.define(...)`.

## Why this shape

Parts are saved separately (`scope`) so a command saves only what it can change: `checkout` saves HEAD, `delete` saves branch tips, `reset` saves branches, HEAD and files.

## Shape

- Fields: id, created_at, reason, scope, worktree_path, head, branches, stashes, index, worktree, skipped_files (`lib/gitflash/snapshot.rb:15-18`).
- `head` = `{ branch:, sha: }`; branch nil when detached, sha nil before first commit (`snapshot.rb:7-8`).
- `index` / `worktree` = commits whose trees are the staged state and the working tree incl. untracked; nil when clean (`snapshot.rb:11-13`).
- `object_ids` = every commit the snapshot must keep reachable (`snapshot.rb:34-36`).
- `state` = all fields except id, time, reason: used to skip a duplicate snapshot (`snapshot.rb:39-41`).
- `scope` values: branches, head, worktree, stashes (`lib/gitflash/snapshots.rb:16`).

## Connected to

- **owned-by:** [[snapshot-store]] persists it
- **joins:** [[state-capture]] builds the state, [[restore]] reads it, [[json-schema]] `$defs/snapshot` (`schema/v1.json:578`)
- **looks-like-but-is-not:** [[commit]] / [[branch]] records; a git stash

## If you change this

- **Hits:** [[json-schema]] `snapshot` def; [[snapshot-store]] JSON metadata (old snapshots are parsed with `from_h`, `snapshot.rb:19-27`, so new fields need defaults); [[state-capture]]; [[restore]]; [[undo]].
- **Does not hit:** [[branch]], [[hook-rules]].
- Snapshots already stored in user repos stay readable only if `from_h` tolerates their shape.

## Surfaces

| Surface | Role |
|---|---|
| agents | read via `snapshots --json`, `undo` |

## See

- Source: `lib/gitflash/snapshot.rb`
