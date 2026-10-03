---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/branches.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Branches command

Read-only list of local branches. Code: `Commands::Branches`.

## Why this shape

Changes nothing, so no confirm and no snapshot. Filters OR together: branch shown if it matches any (`lib/gitflash/commands/branches.rb:15-21`).

## Shape

- Filters: `--merged` (excludes default), `--gone`, `--stale DAYS` (`branches.rb:23-30`).
- Result: `{ default_branch, branches }` (`branches.rb:9`), schema `branches_result`.
- Text: aligned table (`branches.rb:32-64`).
- Calls `repo.branches(merged_status: true)` (`branches.rb:8`), one extra git call.

## Connected to

- **joins:** [[repo]], [[branch]], [[json-schema]], [[cli]] options (`cli.rb:23-30`)
- **looks-like-but-is-not:** cleanup. It only reports. [[delete]] removes.

## If you change this

- **Hits:** [[json-schema]] `branches_result`; agents using the list to pick deletions.
- **Does not hit:** [[delete]] (own checks), [[change-flow]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read |

## See

- Source: `lib/gitflash/commands/branches.rb`
