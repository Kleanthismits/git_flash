---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/branch.rb
verified_on: 2026-10-03
verified_at: dde88fd
---

# Branch

Value record of one local branch. Code: `Branch = Data.define(...)`.

## Why this shape

Immutable `Data` parsed once from `for-each-ref`, so commands filter and report from one source.

## Shape

- 12 fields (`lib/gitflash/branch.rb:7-10`), mirrored by `$defs/branch` in [[json-schema]] (`schema/v1.json:350`).
- `merged` nil when status unknown (`branch.rb:12-13`, `25`).
- `stale?(days)` (`branch.rb:36-38`); `to_h` formats time ISO 8601 (`branch.rb:40-42`).
- Parse order bound to `Repo::BRANCH_FORMAT` (`branch.rb:14`).

## Connected to

- **owned-by:** [[repo]]
- **joins:** [[json-schema]], `branches` and `delete` commands
- **looks-like-but-is-not:** [[snapshot]] `branches` is a plain `{ name => sha }` map, not `Branch` records.

## If you change this

- **Hits:** [[repo]] `BRANCH_FORMAT`; [[json-schema]] `branch` required list; `branches` text columns; `delete` protection checks.
- **Does not hit:** [[commit]], [[exit-codes]], [[snapshot]].

## Surfaces

| Surface | Role |
|---|---|
| agents | read via `branches --json` |

## See

- Source: `lib/gitflash/branch.rb`
