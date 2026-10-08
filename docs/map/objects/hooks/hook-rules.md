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

Only git commands that lose work git cannot restore matter: uncommitted or untracked files, deleted branches, dropped stashes. Commit, merge, pull are ignored because the reflog covers them (`lib/gitflash/hook/command_parser.rb`). Parser is simple on purpose: an extra snapshot is harmless, a missed one is not (`command_parser.rb`).

## Shape

- `RULES` map: reset, checkout, restore, clean, switch, stash, branch, update-ref, rebase, merge/cherry-pick/revert/am (abort only), worktree (`lib/gitflash/hook/rules.rb`). Each returns `{ scope, branches, dir }` or nil.
- Short options may be bundled: `short_flags` joins their letters, so `git checkout -fq main`, `git switch -fq main` and `git clean -fdq` are seen (`rules.rb`).
- `checkout` also counts an argument that names an existing file as a discard (`git checkout src/app.rb`), because telling a path from a branch needs git; this can add an extra snapshot, which is harmless (`rules.rb`).
- Examples: `reset` always saves branches+head+worktree for the current branch (`rules.rb`); `clean` only when forced and not dry-run (`rules.rb`); `branch` only for delete/move/force flags (`rules.rb`).
- Parser: splits on unquoted `; & |` and newlines (`command_parser.rb`), strips `sudo`, `env`, `VAR=x` (`command_parser.rb`, `60-69`), follows `cd` and `git -C` (`command_parser.rb`, `91-98`).
- Commands inside `bash -c`, `sh -c`, `zsh -c` (also `-lc`) and `eval` are parsed too, up to three levels deep (`CommandParser#nested_script`). Bundled branch flags (`git branch -qD x`) and `git clean -i` count as destructive.
- **Known misses:** `echo $(git reset --hard)`, backticks, `xargs git branch -D`, `--git-dir` / `--work-tree` (the repository git really uses), a `cd` that fails, and subshell scope (`(cd x; ...)`). The directory is inferred from the text. Also true for `deny` mode.

- Creation rules are separate: `Hook::Creations` says which commands create a branch (see [[hook-marking]]); `CommandParser#creations` reuses the same `cd` and `-C` walk through `git_commands`.

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
