---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/branch.rb
verified_on: 2026-11-01
verified_at: b55b61e plus unused-branch rule
---

# Branch

Value record of one local branch. Code: `Branch = Data.define(...)`.

## Why this shape

Immutable `Data` parsed once from `for-each-ref`, so commands filter and report from one source.

## Shape

- 15 fields; `unused` and `last_activity_at` are nil until `BranchActivity.annotate` reads the reflogs (one `git log -g` for all branches, `lib/gitflash/branch_activity.rb`; called by [[repo]] `branches(merged_status: true)`). `unused`: the only reflog entry is `branch: Created from`. `owner` is nil until [[ownership]]`#annotate` sets it, so `parse` never reads config (`lib/gitflash/branch.rb`), mirrored by `$defs/branch` in [[json-schema]] (`schema/v1.json:350`).
- `merged` nil when status unknown (`branch.rb`, `25`).
- `stale?(days)`: neither `last_commit_at` nor `last_activity_at` within `days` (`branch.rb`); `to_h` formats time ISO 8601 (`branch.rb`).
- `Branch.parse_tips` and `Branch::TIPS_FORMAT` read `{ name => sha }` from full refs; shared by [[state-capture]] and [[restore]] (`branch.rb`, last line of file).
- Parse order bound to `Repo::BRANCH_FORMAT` (`branch.rb`).

## Connected to

- **owned-by:** [[repo]]
- **joins:** [[ownership]]
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

- Source: `lib/gitflash/branch.rb`, `lib/gitflash/branch_activity.rb`
