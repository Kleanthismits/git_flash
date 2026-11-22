---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/completion.rb
verified_on: 2026-11-22
verified_at: 6fad98e plus shell completion (phase 5)
---

# Completion

`gitflash completion SHELL` prints a bash, zsh or fish completion script. Code: `Completion` reads the Thor tree, `Completion::View` renders one ERB template per shell.

## Why this shape

Built from `Cli`, its subcommand classes and their options at run time, so a new command, option or enum is completed without editing a script. Branch names come from plain `git for-each-ref` inside the script: completing never starts Ruby (about 0.3 s per start).

## Shape

- `Completion` (`lib/gitflash/completion.rb`): `children(group)` = commands at the top level or in a group, `commands` = every runnable command by path (`worktree add`), `global_options`, `value_switches` (options whose next word is a value), `groups`, `aliases` (`wt` from `Cli.map`). `script` refuses an unknown shell with `Thor::Error`.
- Left out: Thor's `tree` (`HIDDEN`) and hidden commands (`hook claude`).
- What a value completes is `:branch`, `:path`, `:directory`, fixed words (an Array) or nothing (`nil`):
  - positional arguments by their usage word, in order (`ARGUMENTS`: `BRANCH`, `SOURCE`, `COMMIT`, `WORKTREE` complete branches, `PATH` paths, `SHELL` the shells). `Command#arguments` holds one value per position; `repeats` when the last one ends in `...` (`delete [BRANCH...]`). `pick [SOURCE] [SHA...]` completes branches only for SOURCE.
  - option values by `enum`, else by banner (`BANNERS`: `REF` branches, `DIR` directories). An option with `lazy_default` (`clean --stale`) is `optional`: the word after it completes as usual.
- Boolean options that default to true also get `--no-<name>` (`pick --no-commit`, `mcp --no-elicitation`).
- Templates `lib/gitflash/completion/{bash,zsh,fish}.erb`, rendered by `View` (`lib/gitflash/completion/view.rb`), which exposes the Completion as `tree` and adds the shell-shaped lists (`value_cases`, `argument_cases`, `fish_arguments`) and quoting. Every script finds the command the same way: the first word that is not an option or an option's value, plus the second word when the first is a group; the words after it are its arguments, counted from 0.
- Branch names: `%(refname:lstrip=2)`, not `refname:short` (a tag of the same name changes the short name).
- **Branch names are untrusted** (an agent or a cloned repo can name a branch `$(...)`). bash never passes them to `compgen -W`, which expands its words: `_gitflash_branches` matches the prefix itself and adds each name quoted with `printf %q`. zsh `compadd` and fish `-a` do not expand candidates. Only static words from the templates go through `compgen -W`.
- `--switch=value`: bash 4 and later split it into `--switch`, `=` and the value (`=` is in `COMP_WORDBREAKS`); bash 3.2 keeps one word. `_gitflash` reads both forms as one value before handing off to `_gitflash_complete`, so the value is never counted as an argument.
- bash registers with `complete -o default`, so it completes file names when the function offers nothing (paths, and any argument that completes nothing).

## Connected to

- **owned-by:** [[cli]] (`Cli#completion`)
- **joins:** every Thor class: `Cli`, `HookCli`, `SkillCli`, `WorktreeCli`
- **looks-like-but-is-not:** not part of the JSON contract; prints a script like `schema` prints the schema

## If you change this

- **Hits:** what users' shells complete; the templates ship through `lib/**/*` in the gemspec; `spec/lib/gitflash/completion_spec.rb` (runs the bash function and fish `complete -C`, parses the zsh script, checks a branch named `$(...)` never runs; skips a shell that is missing, CI installs zsh and fish on every Ruby).
- A renamed usage word or banner changes what that argument completes: check `ARGUMENTS` and `BANNERS`.
- **Does not hit:** [[json-schema]], [[exit-codes]] (an unknown shell is `invalid_usage`, exit 2, from `Cli.start`).
- **Outside-in:** users keep `source <(gitflash completion zsh)` in rc files, or a saved script. Saved scripts stay old until regenerated.

## Surfaces

| Surface | Role |
|---|---|
| humans in bash, zsh, fish | read |

## See

- Source: `lib/gitflash/completion.rb`, `lib/gitflash/completion/`
