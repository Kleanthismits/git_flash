---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/git/bash_command.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Bash command

Process runner for git. Code: `Git::BashCommand`.

## Why this shape

No shell, so no injection from branch names (`Open3.capture3(env, *args)`, `lib/gitflash/git/bash_command.rb:21`).

## Shape

- `exec(*args, env: {})` returns stdout, raises `Git::CommandError` on failure (`bash_command.rb:11-16`).
- `capture(*args, env: {})` returns `[stdout, stderr, success]` (`bash_command.rb:20-25`). `env` applies to that call only. [[state-capture]] uses it for `GIT_INDEX_FILE`, author and date.
- Missing binary becomes `CommandError` (`bash_command.rb:23-24`).
- `CommandError` is an `Error` with code `git_failed` (`lib/gitflash/git/command_error.rb:5-9`).

## Connected to

- **owned-by:** [[repo]], [[snapshot-store]], [[state-capture]], [[restore]], [[hook-claude]] (default dependency in each)
- **joins:** [[exit-codes]]

## If you change this

- **Hits:** every git call, including snapshots and hooks; `spec/lib/gitflash/git/bash_command_spec.rb`.
- **Does not hit:** [[ui-output]], [[json-schema]].

## Surfaces

| Surface | Role |
|---|---|
| core classes | call |

## See

- Source: `lib/gitflash/git/bash_command.rb`
