---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/command_runner.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Command runner

Module mixed into `Cli` and `HookCli`. Runs one command class and maps errors to output and exit status.

## Why this shape

Splits the per-run wiring out of `Cli` so the `hook` subcommand uses the same path. `repo_required:` lets `hook status` and user-scope `hook install` run outside a repository.

## Shape

- `run_command(name, command_class, *, repo_required: true)` (`lib/gitflash/command_runner.rb:8-17`): build `Ui`, build `Repo`, check work tree, call, `exit(status)` unless 0.
- Rescues `Error` only; prints via `Ui#error` and exits `e.exit_code` (`command_runner.rb:14-17`).
- `name` becomes the envelope `command`. Two words for hooks: `hook install`, `hook status` (`lib/gitflash/hook_cli.rb:56`, `66`).

## Connected to

- **owns:** [[ui-output]], [[repo]] instances per run
- **owned-by:** [[cli]], `HookCli`
- **joins:** [[exit-codes]]

## If you change this

- **Hits:** every command's setup and exit path; the `command` enum in [[json-schema]].
- **Does not hit:** command logic; `hook claude` (bypasses it, see [[hook-claude]]).

## Surfaces

| Surface | Role |
|---|---|
| [[cli]] | calls |

## See

- Source: `lib/gitflash/command_runner.rb`
