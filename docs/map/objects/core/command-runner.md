---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/command_runner.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the error envelope fix (#46)
---

# Command runner

Module mixed into `Cli` and `HookCli`. Runs one command class and maps errors to output and exit status.

## Why this shape

Splits the per-run wiring out of `Cli` so the `hook` subcommand uses the same path. `repo_required:` lets `hook status` and user-scope `hook install` run outside a repository.

## Shape

- `run_command(name, command_class, *, repo_required: true)` (`lib/gitflash/command_runner.rb:8-17`): build `Ui`, build `Repo`, check work tree, call, `exit(status)` unless 0.
- Rescues `Error`, prints via `Ui#error` and exits `e.exit_code`; any other `StandardError` becomes an `Error` (`failed`, exit 1, message `NAME failed unexpectedly: ...`) in `report_unexpected`, so `--json` always gets the envelope (`command_runner.rb`).
- Thor's own errors (bad option value, unknown command) never reach here: `Cli.start` rescues `Thor::Error` and prints it with `UsageReport` (`lib/gitflash/usage_report.rb`) as `invalid_usage`, exit 2; with `--json` in the envelope, `command` taken from the arguments (`gitflash` when none is known).
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
