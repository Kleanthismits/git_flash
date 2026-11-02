---
type: object
cluster: contract
universe: live
status: verified
entity: lib/gitflash/ui.rb
verified_on: 2026-10-24
verified_at: 6b41e31 plus the --confirm token (#42)
---

# UI output

All user-visible output, text or JSON. Product: "report". Code: `Ui`.

## Why this shape

Commands never print. They call `report` with a plan, result and optional `undo`; `Ui` picks text or the JSON envelope. One status vocabulary for both.

## Shape

- `JSON_SCHEMA_VERSION = 1`, `OK_STATUSES` (`lib/gitflash/ui.rb:12-13`).
- `report(status:, text:, **fields)` prints and returns exit status (`ui.rb:37-45`). Text mode appends `Undo with: gitflash undo ID` when `undo:` is a snapshot, plus a note when it is reused (`Ui#undo_hint`).
- `envelope` turns `undo:` into `{ snapshot:, command: }`, adding `reused: true` for a reused snapshot, and drops nil keys (`ui.rb:77-90`).
- `error` prints envelope or warns (`ui.rb:47-54`). It never adds `undo`.
- `interactive?` = not JSON and stdin is a tty (`ui.rb:30-32`). JSON mode never prompts.
- `confirm?` true on `--yes`; raises `ConfirmationRequired` with plan when not interactive (`ui.rb`). With `irreversible: true` (a change `gitflash undo` cannot revert) `--yes` is not enough: it needs `--confirm TOKEN`, where `Ui.confirm_token(plan)` is the first 8 hex digits of SHA-256 over the plan's JSON, so a token never confirms a different plan. Without it, `ConfirmationRequired` carries `confirm_token`, which `Ui#error` adds to `error` in JSON; in a terminal the user types the token (`Prompt#ask`). Used by `gc`.

## Connected to

- **owned-by:** built in `CommandRunner#build_ui` (`lib/gitflash/command_runner.rb:19-21`)
- **joins:** [[json-schema]], [[exit-codes]], [[change-flow]], prompt wrapper `lib/gitflash/prompt.rb`
- **looks-like-but-is-not:** [[repo]] never prints. [[hook-claude]] prints its own JSON and does not use `Ui`.

## If you change this

- **Hits:** every command, [[json-schema]] validity, exit status, `--yes` / `--dry-run` / `--json`, the undo hint agents read.
- **Does not hit:** [[repo]], [[branch]], git calls, [[hook-claude]] output.

## Surfaces

| Surface | Role |
|---|---|
| terminal user | reads text, answers prompts |
| agents | read JSON |

## See

- Source: `lib/gitflash/ui.rb`
