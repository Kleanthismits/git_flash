---
type: object
cluster: snapshots
universe: live
status: verified
entity: lib/gitflash/restore.rb
verified_on: 2026-10-05
verified_at: 0b7b8d9 plus review fixes
---

# Restore

Plans and applies the restore of a snapshot. Code: `Restore`.

## Why this shape

Restores only the parts in the snapshot's scope, and only where the repo differs. Branches created after the snapshot are left alone, and so are unstaged untracked files (`lib/gitflash/restore.rb:4-6`). Two exceptions, both checked 2026-10-05: a file staged after the snapshot, and absent from it, is removed from index and working tree; an ignored untracked file is overwritten when its path exists in the target tree. The "before undo" snapshot saves the staged file, but not ignored files.

## Shape

- `plan` = `{ branches, head, worktree, stashes }` (`restore.rb:13-21`); `empty?` means nothing to do (`restore.rb:23-25`).
- Step order: branches, HEAD, worktree, stashes (`restore.rb:38-40`).
- Branch step: `update-ref` with the old value as guard; a branch to recreate passes an empty old value, so git refuses if the branch was created since planning (`restore.rb:42-47`).
- With worktree scope HEAD moves via `symbolic-ref` / `update-ref`, else a normal `checkout` keeps local changes (`restore.rb:48-61`).
- Files: `read-tree --reset -u`, then the staged state (`restore.rb:63-70`). Stashes: `stash store` (`restore.rb:72-74`).
- Branch tips and HEAD are read from full refs with `refs/heads/` removed (`Branch.parse_tips`, `restore.rb:93-96`, `115-117`); HEAD is switched with `git switch --` (`restore.rb:59`). Short names change when a tag has the same name.
- `apply` stops at the first failing step and returns its `Result`; there is no rollback (`restore.rb:27-34`).

## Connected to

- **owned-by:** [[undo]]
- **joins:** [[snapshot]], [[bash-command]]
- **looks-like-but-is-not:** `git reset` / `git checkout`; [[state-capture]] is the opposite direction

## If you change this

- **Hits:** [[undo]] plan text and `plan` JSON (`undo_plan` in [[json-schema]]); what an agent gets back after a bad change.
- **Does not hit:** [[snapshot-store]], [[hook-rules]].
- Failure after a partial apply is covered by the "before undo" snapshot in [[undo]], not by Restore.

## Surfaces

| Surface | Role |
|---|---|
| [[undo]] | plans and applies |

## See

- Source: `lib/gitflash/restore.rb`
