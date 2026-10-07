---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/checkout.rb
verified_on: 2026-10-05
verified_at: 0b7b8d9 plus review fixes
---

# Checkout command

Switch to a local branch. Code: `Commands::Checkout`.

## Why this shape

No confirmation; reversible. It saves a HEAD snapshot and also records `previous_branch`, so the caller can go back either way.

## Shape

- No arg needs a terminal (`lib/gitflash/commands/checkout.rb`), else menu defaulting to current (`checkout.rb`).
- Unknown name raises `unknown_branch` (`checkout.rb`). Already there gives `noop` (`checkout.rb`).
- `--dry-run` gives `planned` (`checkout.rb`).
- Snapshot scope `head` (`checkout.rb`); result `{ branch, previous_branch }` plus `undo:` (`checkout.rb`).

## Connected to

- **joins:** [[repo]] `checkout`, [[change-flow]], [[json-schema]] `checkout_*`
- **looks-like-but-is-not:** `git checkout`. `Repo#checkout` runs `git switch -- NAME` (`repo.rb`): it never discards local changes or reads the name as a file path, but a switch still updates tracked files when the branches differ, and it refuses when local changes would be overwritten.

## If you change this

- **Hits:** [[json-schema]] `checkout_plan` / `checkout_result`; [[cli]] arg handling; snapshot count (one per checkout).
- **Does not hit:** [[delete]], [[reset]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/checkout.rb`
