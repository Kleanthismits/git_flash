---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/worktrees.rb
verified_on: 2026-10-05
verified_at: 5fc049d
---

# Worktrees

The worktrees of the repository as `Worktree` records. Code: `Worktrees`, `Worktree`. Not `Snapshot#worktree` (saved file tree) and not `wrong_worktree` (undo guard).

## Why this shape

All parsing of `git worktree list --porcelain` and the per-worktree probes live here. Commands (`wt list`, later `wt remove`, `wt clean`, `clean`) get records and never see porcelain text.

## Shape

- `list`: main checkout first. Fields: path, head, branch (nil when detached), main, bare, locked, lock_reason, missing, dirty, ahead, behind, merged (`lib/gitflash/worktree.rb:5-11`).
- `missing` = git says prunable or directory absent. `dirty` is nil when missing or bare, else `git -C path status --porcelain` (`lib/gitflash/worktrees.rb`).
- ahead, behind, merged come from [[repo]] `branches(merged_status: true)`; nil without a branch.

## Connected to

- **joins:** [[repo]], [[bash-command]], [[branch]], [[json-schema]] `worktree`
- **looks-like-but-is-not:** [[snapshot]] `worktree_path`, `wrong_worktree` in [[undo]]

## If you change this

- **Hits:** [[worktree-commands]], [[json-schema]] `worktree` and `worktree_list_result`.
- **Does not hit:** [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read |

## See

- Source: `lib/gitflash/worktrees.rb`, `lib/gitflash/worktree.rb`
