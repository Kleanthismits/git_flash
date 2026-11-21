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

- `Completion` (`lib/gitflash/completion.rb`): `children(group)` = commands at the top level or in a group, `commands` = every runnable command by path (`worktree add`), `global_options`, `value_switches` (options whose next word is a value), `groups`, `aliases` (`wt` from `Cli.map`).
- Left out: Thor's `tree` (`HIDDEN`) and hidden commands (`hook claude`).
- A command completes branch names when its usage names `BRANCH`, `SOURCE`, `COMMIT` or `WORKTREE` (`BRANCH_ARGUMENTS`). Fixed argument words: `ARGUMENT_WORDS` (`completion` takes `SHELLS`).
- Boolean options that default to true also get `--no-<name>` (`pick --no-commit`, `mcp --no-elicitation`).
- Templates `lib/gitflash/completion/{bash,zsh,fish}.erb`, read by `View` (`lib/gitflash/completion/view.rb`: tree in the shapes the scripts need, quoting per shell). Every script finds the command the same way: the first word that is not an option or an option's value, plus the second word when the first is a group. Option values (`enum`) are completed per command, so `hook install --scope` and `skill install --scope` differ.
- Branch names: `%(refname:lstrip=2)`, not `refname:short` (a tag of the same name changes the short name).

## Connected to

- **owned-by:** [[cli]] (`Cli#completion`)
- **joins:** every Thor class: `Cli`, `HookCli`, `SkillCli`, `WorktreeCli`
- **looks-like-but-is-not:** not part of the JSON contract; prints a script like `schema` prints the schema

## If you change this

- **Hits:** what users' shells complete; the templates ship through `lib/**/*` in the gemspec; `spec/lib/gitflash/completion_spec.rb` (runs the bash function and fish `complete -C`, parses the zsh script; skips a shell that is missing, CI installs zsh and fish).
- **Does not hit:** [[json-schema]], [[exit-codes]] (an unknown shell is `invalid_usage`, exit 2, from `Cli.start`).
- **Outside-in:** users keep `source <(gitflash completion zsh)` in rc files, or a saved script. Saved scripts stay old until regenerated.

## Surfaces

| Surface | Role |
|---|---|
| humans in bash, zsh, fish | read |

## See

- Source: `lib/gitflash/completion.rb`, `lib/gitflash/completion/`
