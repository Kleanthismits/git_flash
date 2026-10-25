---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/undo.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the own-worktree default (#44)
---

# Undo command

Restore a snapshot; by default the latest one taken in this worktree. Code: `Commands::Undo`. The answer to "how do I revert this".

## Why this shape

Saves the current state first, so an undo can itself be undone (`lib/gitflash/commands/undo.rb`, `45-53`). The report carries `undo: before`.

## Shape

- Flow: find, check worktree, plan, empty gives noop, dry-run, confirm, snapshot, apply, report (`undo.rb`, `37-53`).
- Snapshot of a worktree whose directory is gone: [[worktree-revival]] adds the worktree again (branch recreated if deleted), then restores its files. Plan carries `recreate_worktree`; the "before" snapshot saves branches only, so undoing that undo does not remove the worktree again.
- Unknown id raises `unknown_snapshot` (`undo.rb`). Head/worktree snapshot from another worktree raises `wrong_worktree` (`undo.rb`).
- Always confirms unless `--yes` (`undo.rb`). Restore failure raises `git_failed` naming the "before" snapshot (`undo.rb`).
- Without an ID, `Undo#find` takes the newest snapshot whose `worktree_path` is this worktree's `toplevel` (`own?`; snapshots without a path count too). The store is shared by all worktrees, so the newest one overall may be another agent's; an ID restores a snapshot taken elsewhere only when it saved branches alone; one with HEAD or files raises `wrong_worktree` and must be restored in its own worktree (a snapshot without `worktree_path` counts as this worktree's, in `removed_worktree?` and `check_worktree!` too). The plan carries `reason`, so the agent can see which change it is undoing.
- No snapshots of this worktree gives `noop`, and the text says to pass an ID for one taken elsewhere (`undo.rb`).

## Connected to

- **owns:** [[restore]]
- **joins:** [[snapshot-store]], [[change-flow]], [[json-schema]] `undo_*`, [[repo]] `toplevel`
- **looks-like-but-is-not:** `git reset --hard`; Claude Code `/rewind` (only edits Claude made)

## If you change this

- **Hits:** [[json-schema]] `undo_plan` / `undo_result`; the `gitflash undo ID` string printed by [[ui-output]] and [[hook-claude]]; agents relying on undo-of-undo.
- **Does not hit:** [[delete]], [[reset]] logic; [[hook-rules]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/undo.rb`
