---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/worktree_revival.rb
verified_on: 2026-10-05
verified_at: 15af952
---

# Worktree revival

Undo of a removed worktree. Code: `WorktreeRevival`; chosen by `Commands::Undo#build_restore` when the snapshot's `worktree_path` no longer exists.

## Why this shape

`wt remove` deletes the directory, so there is nowhere to restore HEAD and files into. Revival adds the worktree again, then runs the normal [[restore]] inside it. It has the same interface as `Restore` (`plan`, `scope`, `empty?`, `apply`), so [[undo]] needs no second flow.

## Shape

- `plan`: branch moves from `Restore#plan`, head target, `worktree` true when files were saved, `recreate_worktree` path (`lib/gitflash/worktree_revival.rb`).
- `apply`: branch tips first (`Restore#apply(only: :branches)`, so a branch deleted or moved since is back at its saved tip), then `Worktrees#attach` (checks that tip out, so files match HEAD; detached HEAD supported), then `Restore` through `Git::InDirectory` so every git call runs with `git -C path`.
- A failed revival names the added directory and `gitflash wt remove PATH --force` in the error: the "before" snapshot cannot take the worktree away again (`Commands::Undo#revival_hint`).
- The "before undo" snapshot has scope `branches` only.
- Snapshots of a removed worktree are taken through `Git::InDirectory` too: `StateCapture` uses absolute git paths so it works from any directory.

## Connected to

- **joins:** [[restore]], [[undo]], [[worktrees]], [[snapshot-store]], [[json-schema]] `undo_plan.recreate_worktree`
- **looks-like-but-is-not:** `git worktree repair`

## If you change this

- **Hits:** [[undo]], [[worktree-commands]] (`wt remove` snapshot scope), `Git::InDirectory`.
- **Does not hit:** [[delete]], [[reset]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write (through `undo`) |

## See

- Source: `lib/gitflash/worktree_revival.rb`, `lib/gitflash/git/in_directory.rb`
