---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/undo.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Undo command

Restore a snapshot, latest by default. Code: `Commands::Undo`. The answer to "how do I revert this".

## Why this shape

Saves the current state first, so an undo can itself be undone (`lib/gitflash/commands/undo.rb`, `45-53`). The report carries `undo: before`.

## Shape

- Flow: find, check worktree, plan, empty gives noop, dry-run, confirm, snapshot, apply, report (`undo.rb`, `37-53`).
- Snapshot of a worktree whose directory is gone: [[worktree-revival]] adds the worktree again (branch recreated if deleted), then restores its files. Plan carries `recreate_worktree`; the "before" snapshot saves branches only, so undoing that undo does not remove the worktree again.
- Unknown id raises `unknown_snapshot` (`undo.rb`). Head/worktree snapshot from another worktree raises `wrong_worktree` (`undo.rb`).
- Always confirms unless `--yes` (`undo.rb`). Restore failure raises `git_failed` naming the "before" snapshot (`undo.rb`).
- No snapshots gives `noop` (`undo.rb`).

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
