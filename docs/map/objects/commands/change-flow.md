---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/base.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Change flow

Shared steps for commands that change the repo: plan, confirm, snapshot, execute, report. Roadmap standard 1. Spread over `Commands::Base`, `Ui#confirm?`, `Prompt`.

## Why this shape

Agents get the plan back (`confirmation_required` with `plan`), re-run with `--yes`, and every executed change reports an `undo` snapshot. Humans get a prompt.

## Shape

- Helpers in `Base`: `snapshots`, `take_snapshot`, `planned`, `cancelled`, `usage_error!`, `git_error!`, `require_interactive!` (`lib/gitflash/commands/base.rb:17-44`).
- Gate: `Ui#confirm?` (`lib/gitflash/ui.rb:66-73`); prompt text via `Prompt#proceed_with_warning` (`lib/gitflash/prompt.rb:26-32`).
- Per command (order matters):

| Command | Confirm | Snapshot scope | Snapshot taken |
|---|---|---|---|
| checkout | none | head | after dry-run, before git (`checkout.rb:35`) |
| delete | always | branches (the names) | after confirm (`delete.rb:59-60`) |
| reset | `--hard` only (`reset.rb:64-66`) | branches, head, worktree | before git, all modes (`reset.rb:51`, `59-61`) |
| undo | always | scope of target | after confirm (`undo.rb:46`) |
| gc | always | none | deletes snapshots (`gc.rb:21-28`) |

- `delete` reports `undo` only when something was deleted (`delete.rb:87`).
- Snapshot failure raises before the change runs.

## Connected to

- **joins:** [[ui-output]], [[exit-codes]] (`ConfirmationRequired` = 2), [[json-schema]], [[snapshot-store]]
- **looks-like-but-is-not:** one shared method. Each command calls the steps itself, so a new command can forget one.

## If you change this

- **Hits:** [[checkout]], [[delete]], [[reset]], [[undo]], [[snapshot-commands]]; `confirmation_required` and `undo` JSON agents read.
- **Does not hit:** [[repo]], [[branch]], [[hook-claude]] (own path, takes snapshots without these commands).
- New changing command: copy the order above, add it to the `command` enum in [[json-schema]].

## Surfaces

| Surface | Role |
|---|---|
| agents | re-run with `--yes`; read `undo` |
| terminal user | answers prompt |

## See

- Source: `lib/gitflash/commands/base.rb`
