---
type: object
cluster: contract
universe: live
status: verified
entity: lib/gitflash/ui.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# UI output

All user-visible output, text or JSON. Product: "report". Code: `Ui`.

## Why this shape

Commands never print. They call `report` with a plan, result and optional `undo`; `Ui` picks text or the JSON envelope. One status vocabulary for both.

## Shape

- `JSON_SCHEMA_VERSION = 1`, `OK_STATUSES` (`lib/gitflash/ui.rb:12-13`).
- `report(status:, text:, **fields)` prints and returns exit status (`ui.rb:37-45`). Text mode appends `Undo with: gitflash undo ID` when `undo:` is a snapshot (`ui.rb:42`).
- `envelope` turns `undo:` into `{ snapshot:, command: }` and drops nil keys (`ui.rb:77-90`).
- `error` prints envelope or warns (`ui.rb:47-54`). It never adds `undo`.
- `interactive?` = not JSON and stdin is a tty (`ui.rb:30-32`). JSON mode never prompts.
- `confirm?` true on `--yes`; raises `ConfirmationRequired` with plan when not interactive (`ui.rb:66-73`).

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
