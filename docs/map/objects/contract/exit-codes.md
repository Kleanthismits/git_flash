---
type: object
cluster: contract
universe: live
status: verified
entity: lib/gitflash/error.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Exit codes

Process exit status plus stable error `code`. Code: `Error` hierarchy.

## Why this shape

Agents branch on exit status and `error.code`, not message text. 2 means "fix the call or confirm and retry"; 1 means "git or environment failed".

## Shape

- 0: status done / planned / noop / cancelled (`lib/gitflash/ui.rb:44`).
- 1: `Error` default (`lib/gitflash/error.rb:15-17`), `failed` report (`ui.rb:44`), `Git::CommandError` (`lib/gitflash/git/command_error.rb:5`).
- 2: `UsageError` (`lib/gitflash/usage_error.rb:10-12`), `ConfirmationRequired` (`lib/gitflash/confirmation_required.rb:11-13`).
- Each error carries `code`, optional `plan`, `status` (`error.rb:8-22`).
- Codes are in the schema enum (`schema/v1.json:315-342`). Snapshot-era additions: `unknown_snapshot` (`lib/gitflash/commands/undo.rb`), `wrong_worktree` (`undo.rb`), `invalid_settings` (`lib/gitflash/hook/settings.rb:49`), `invalid_config` (`lib/gitflash/config.rb`), `conflict` (`lib/gitflash/commands/pick_outcome.rb`, status `failed`, exit 1), `unknown_worktree` and `protected_worktree` (`lib/gitflash/commands/worktree_{command,remove,move}.rb`).
- `gitflash hook claude` is the exception: it rescues everything and exits 0 (`lib/gitflash/hook_cli.rb:33-35`).
- `CommandRunner` rescues only `Error` (`lib/gitflash/command_runner.rb:14-17`).

## Connected to

- **owned-by:** raised in [[repo]], [[change-flow]], commands, [[hook-install]]
- **joins:** [[json-schema]] enum, [[ui-output]] `error`, [[command-runner]]
- **looks-like-but-is-not:** `Git::CommandError` is raised by [[bash-command]] and rescued in [[repo]] (`repo.rb`, `61`, `103`); it is not always a user-facing exit

## If you change this

- **Hits:** [[json-schema]] enums; every `usage_error!` and `git_error!` caller; agent scripts reading exit status.
- **Does not hit:** git behavior; text of success output.
- New code string: add to schema enum. Checked 2026-10-03: all codes in `lib/` match the enum.
- Quirk: `Delete#failure` hardcodes the error hash (`lib/gitflash/commands/delete.rb`) instead of using an `Error`. Keep in sync by hand.
- A snapshot failure raises `git_failed` before the change runs, so the change is blocked ([[change-flow]]).

## Surfaces

| Surface | Role |
|---|---|
| agents, shells | read status |
| rspec | asserts |

## See

- Source: `lib/gitflash/error.rb`
