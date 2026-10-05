---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/rules.rb
verified_on: 2026-10-05
verified_at: 337d6bc plus bundled-flag fix
---

# Hook rules and parser

Decides which shell commands are dangerous and what to save first. Code: `Hook::Rules` and `Hook::CommandParser`.

## Why this shape

Only git commands that lose work git cannot restore matter: uncommitted or untracked files, deleted branches, dropped stashes. Commit, merge, pull are ignored because the reflog covers them (`lib/gitflash/hook/command_parser.rb:7-11`). Parser is simple on purpose: an extra snapshot is harmless, a missed one is not (`command_parser.rb:12-14`).

## Shape

- `RULES` map: reset, checkout, restore, clean, switch, stash, branch, update-ref, rebase, merge/cherry-pick/revert/am (abort only), worktree (`lib/gitflash/hook/rules.rb:75-90`). Each returns `{ scope, branches, dir }` or nil.
- Short options may be bundled: `short_flags` joins their letters, so `git checkout -fq main`, `git switch -fq main` and `git clean -fdq` are seen (`rules.rb:24-33`).
- `checkout` also counts an argument that names an existing file as a discard (`git checkout src/app.rb`), because telling a path from a branch needs git; this can add an extra snapshot, which is harmless (`rules.rb:22-34`).
- Examples: `reset` always saves branches+head+worktree for the current branch (`rules.rb:76`); `clean` only when forced and not dry-run (`rules.rb:27-33`); `branch` only for delete/move/force flags (`rules.rb:46-50`).
- Parser: splits on unquoted `; & |` and newlines (`command_parser.rb:43-58`), strips `sudo`, `env`, `VAR=x` (`command_parser.rb:19`, `60-69`), follows `cd` and `git -C` (`command_parser.rb:32-35`, `91-98`).
- **Known miss, checked 2026-10-03:** `bash -c "git reset --hard"`, `echo $(git reset --hard)`, `sh -c "cd x && git clean -fd"` and `xargs git branch -D` return no target; `(git reset --hard)` and `git stash drop` do. Also true for `deny` mode.

## Connected to

- **owned-by:** [[hook-claude]]
- **joins:** [[snapshot]] `scope` values
- **looks-like-but-is-not:** `gitflash`'s own commands, which are protected by [[change-flow]]

## If you change this

- **Hits:** which agent commands get a snapshot or a block; `spec/lib/gitflash/hook/command_parser_spec.rb`.
- **Does not hit:** [[snapshot-store]], [[restore]], [[json-schema]].
- Adding a git subcommand: add a rule and a spec; a rule that returns a scope outside `Snapshots::SCOPES` is dropped by [[state-capture]].

## Surfaces

| Surface | Role |
|---|---|
| [[hook-claude]] | calls |

## See

- Source: `lib/gitflash/hook/rules.rb`, `lib/gitflash/hook/command_parser.rb`
