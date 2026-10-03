---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/checkout.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Checkout command

Switch to a local branch. Code: `Commands::Checkout`.

## Why this shape

No confirmation; reversible. It saves a HEAD snapshot and also records `previous_branch`, so the caller can go back either way.

## Shape

- No arg needs a terminal (`lib/gitflash/commands/checkout.rb:12`), else menu defaulting to current (`checkout.rb:23-26`).
- Unknown name raises `unknown_branch` (`checkout.rb:29`). Already there gives `noop` (`checkout.rb:30`).
- `--dry-run` gives `planned` (`checkout.rb:33`).
- Snapshot scope `head` (`checkout.rb:35`); result `{ branch, previous_branch }` plus `undo:` (`checkout.rb:38-40`).

## Connected to

- **joins:** [[repo]] `checkout`, [[change-flow]], [[json-schema]] `checkout_*`
- **looks-like-but-is-not:** `git checkout` (never touches files; passes `--`, `repo.rb:72-74`)

## If you change this

- **Hits:** [[json-schema]] `checkout_plan` / `checkout_result`; [[cli]] arg handling; snapshot count (one per checkout).
- **Does not hit:** [[delete]], [[reset]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/checkout.rb`
