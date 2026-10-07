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

The worktrees of the repository as `Worktree` records, and the git calls that add or remove them. Code: `Worktrees`, `Worktree`. Not `Snapshot#worktree` (saved file tree) and not `wrong_worktree` (undo guard).

## Why this shape

All parsing of `git worktree list --porcelain` and the per-worktree probes live here. Commands (`wt list`, later `wt remove`, `wt clean`, `clean`) get records and never see porcelain text.

## Shape

- `list`: main checkout first. Fields: path, head, branch (nil when detached), main, bare, locked, lock_reason, missing, dirty, ahead, behind, merged, owner (`lib/gitflash/worktree.rb:5-11`).
- `missing` = git says prunable or directory absent. `dirty` is nil when missing or bare, else `git -C path status --porcelain` (`lib/gitflash/worktrees.rb`).
- Writes: `add` (`source_for` picks existing / remote / new), `remove` (`--force --force` for locked or dirty), `lock`, `unlock`, `move`, `prune`, `attach` (for undo: reuses a registered but missing directory) return `Result`.
- `Worktree#removal_blocker(force:, current:)` is the one rule for what may be removed.
- `ignored(path)`: ignored files and directories (directory counts once), for the removal warning.
- Lists with `--porcelain -z`, so paths with newlines and lock reasons survive.
- ahead, behind, merged, owner come from [[repo]] `branches(merged_status: true)`; nil without a branch.

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
