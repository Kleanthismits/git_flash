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

Saves the current state first, so an undo can itself be undone (`lib/gitflash/commands/undo.rb:5-6`, `45-53`). The report carries `undo: before`.

## Shape

- Flow: find, check worktree, plan, empty gives noop, dry-run, confirm, snapshot, apply, report (`undo.rb:8-18`, `37-53`).
- Unknown id raises `unknown_snapshot` (`undo.rb:25`). Head/worktree snapshot from another worktree raises `wrong_worktree` (`undo.rb:29-35`).
- Always confirms unless `--yes` (`undo.rb:40`). Restore failure raises `git_failed` naming the "before" snapshot (`undo.rb:55-59`).
- No snapshots gives `noop` (`undo.rb:61-63`).

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
