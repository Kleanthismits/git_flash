---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/rules.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the fixes for #34 to #38
---

# Hook rules and parser

Decides which shell commands are dangerous and what to save first. Code: `Hook::Rules` and `Hook::CommandParser`.

## Why this shape

Only git commands that lose work git cannot restore matter: uncommitted or untracked files, deleted branches, dropped stashes. Commit, merge, pull are ignored because the reflog covers them (`lib/gitflash/hook/command_parser.rb`). Parser is simple on purpose: an extra snapshot is harmless, a missed one is not (`command_parser.rb`).

## Shape

- `RULES` map: reset, checkout, restore, clean, switch, stash, branch, update-ref, rebase, merge/cherry-pick/revert/am (abort only), worktree (`lib/gitflash/hook/rules.rb`), plus `HistoryRules::RULES` (`lib/gitflash/hook/history_rules.rb`): `rm -f` (not `--cached`), `checkout-index -f`, `read-tree -u --reset`, `reflog expire|delete`, `gc --prune=now|all`, `prune`, and `push . :branch` / `push . --delete branch` (a name the shell or xargs fills in, or `--delete` with no names, saves every branch). Each returns `{ scope, branches, dir }` or nil.
- `branch` deletions whose names the shell or xargs fills in (`$b`, `{}`) save every branch (empty `branches`). When targets of one directory are merged, an empty `branches` with the `branches` scope wins (`CommandParser::Target.merge`), so a named deletion cannot narrow an unnamed one.
- `worktree remove` counts without `--force` too: git deletes the worktree's ignored files either way. `clean` without `-f` counts when `git config clean.requireForce` is false in that directory (`Rules.require_force?`, one git call, only when no force flag is given). `update-ref --stdin` saves every branch (the refs come from input).
- Reflog and prune rules save the current state (`FULL`); commits that only the reflog pointed at are not saved by a snapshot.
- Short options may be bundled: `short_flags` joins their letters, so `git checkout -fq main`, `git switch -fq main` and `git clean -fdq` are seen (`rules.rb`).
- `checkout` also counts an argument that names an existing file as a discard (`git checkout src/app.rb`), because telling a path from a branch needs git; this can add an extra snapshot, which is harmless (`rules.rb`).
- Examples: `reset` always saves branches+head+worktree for the current branch (`rules.rb`); `clean` only when forced and not dry-run (`rules.rb`); `branch` only for delete/move/force flags (`rules.rb`).
- Parser: splits on unquoted `; & |` and newlines, never inside `$(...)` or backticks, and honours backslash escapes outside single quotes (`Hook::ShellText.segments`, `lib/gitflash/hook/shell_text.rb`; one scan with `substitutions`, which follows quotes as the shell does: nothing runs in single quotes, `$(...)` and backticks run in double quotes, an escaped backtick or a quoted `)` does not close a substitution), reads each segment's words with `Hook::CommandWords` (`command_words.rb`: drops redirections such as `> out` and `2>&1`, keywords, `VAR=x` assignments, kept as `env`), strips wrappers and their options with `Hook::Wrappers` (`wrappers.rb`: `sudo`, `env`, `command`, `exec`, `time`, `nohup`, `nice`, `ionice`, `stdbuf`, `timeout DURATION`, `xargs`, also by path such as `/usr/bin/env`; `sudo -D` and `env -C` change the directory; `find -exec CMD ;`), follows `cd`, `pushd` / `popd` (a stack per line; `popd` with nothing pushed goes back to the hook's `cwd`) and `git -C`. Assignments after `env` or `sudo` (`env GIT_DIR=...`) are kept in `env` like leading ones.
- `Hook::GitInvocation` (`git_invocation.rb`) reads git's global options: `-C`, `--work-tree`, `--git-dir` (both `--x=v` and `--x v`) and `GIT_WORK_TREE` / `GIT_DIR` assignments choose the directory to snapshot (the work tree, else the parent of a `.git` dir). An alias from `-c alias.NAME=...` or the repository's config (`GitInvocation.configured_aliases`, one `git config --get-regexp` per directory, cached) is replaced by what it stands for, following alias chains up to `MAX_ALIAS_DEPTH` (10); a `!` alias is parsed as a script. Aliases are not read for `CommandParser::BUILTINS` (git never lets an alias replace a built-in), so common commands such as `git status` cost no extra git call. Paths go through `Hook::Paths.expand` (`lib/gitflash/hook/paths.rb`), which keeps `~unknownuser` as a literal name instead of raising; `checkout`'s path test and `worktree remove` use it too, so an odd path never stops the hook from deciding. A `cd` or `-C` path the shell decides when it runs (`$VAR`, `$(...)`, backticks, `cd -`; `Paths.unresolved?`) falls back to the hook's `cwd` as a `Paths::Guessed` directory (`Paths.change_dir`; a relative `cd` from a guessed directory stays guessed, an absolute one does not), so the snapshot lands in the directory Claude runs in instead of a directory that does not exist, and the target's `guessed` flag tells [[hook-claude]] to say so.
- Shell comments (an unquoted `#` that starts a word, to the end of the line) are skipped (`ShellText.comment?`), so an apostrophe in one cannot open a quote. Where quotes and substitutions end is in `Hook::ShellQuotes` (`shell_quotes.rb`).
- Shell keywords before a command are skipped (`if`, `then`, `else`, `elif`, `do`, `while`, `until`, `!`, `{`; `CommandParser::KEYWORDS`), so `if ...; then git reset --hard; fi` and loops are seen.
- Commands inside `$(...)`, `<(...)`, `>(...)` and backticks are parsed as scripts of their own, in the directory of their segment (`ShellText.substitutions`, `CommandParser#substituted`); text in single quotes or after a backslash is left alone. They share the three-level limit below. Past that limit a script that mentions `git` is not read but counts as risky (`CommandParser#nested`, `Rules::UNREAD`, full scope), so deep nesting cannot hide a command; the same applies to `bash -c` nesting.
- Commands inside `bash -c`, `sh -c`, `zsh -c` (also `-lc`) and `eval` are parsed too, up to three levels deep (`CommandParser#nested_script`). Bundled branch flags (`git branch -qD x`) and `git clean -i` count as destructive.
- **Known misses:** the names of the branches `xargs git branch -D` deletes (read from stdin; [[hook-claude]] then saves every branch), shell functions and shell aliases, `GIT_DIR` exported in an earlier command, a `cd` that fails, a `cd "$VAR"` that leaves Claude's repository (the snapshot lands in Claude's directory), and subshell scope (`(cd x; ...)`). The directory is inferred from the text. Also true for `deny` mode.

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

- Source: `lib/gitflash/hook/rules.rb`, `lib/gitflash/hook/command_parser.rb`, `lib/gitflash/hook/paths.rb`, `lib/gitflash/hook/shell_text.rb`, `lib/gitflash/hook/shell_quotes.rb`, `lib/gitflash/hook/command_words.rb`, `lib/gitflash/hook/wrappers.rb`, `lib/gitflash/hook/git_invocation.rb`
