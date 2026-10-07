---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/cleanup.rb
verified_on: 2026-10-05
verified_at: 57536c8
---

# Cleanup

What `clean` and `wt clean` would remove, and which branches are never touched. Code: `Cleanup` (module of pure functions), `Cleanup::Rules`, `Protection`.

## Why this shape

All selection rules in one place that runs no git command, so each rule is tested with plain records. Commands only gather records and act on the answer.

## Shape

- `Cleanup::Rules(criteria, stale_days, now)#reasons(branch)`: labels `merged`, `upstream gone`, `no commits for N days`, `agent-created` (`lib/gitflash/cleanup.rb`).
- `Cleanup.branches(branches, rules:, protection:)` returns `Candidate(item, reasons)`.
- `Cleanup.worktrees(...)` returns `[chosen, skipped]`; a `blocker` lambda says why a match may not be removed (`Worktree#removal_blocker`), such a match is skipped with the reason.
- `Protection#protected?`: current, default, `main`, `master`, [[config]] `protected`, branches checked out in worktrees (`lib/gitflash/protection.rb`). Also used by [[delete]].
- `:merged` never matches the default branch.

## Connected to

- **joins:** [[branch]], [[worktrees]], [[config]], [[ownership]]
- **owned-by:** [[clean]], [[worktree-commands]] (`wt clean`), [[delete]] (Protection)

## If you change this

- **Hits:** `clean`, `wt clean`, `delete` refusals; `spec/lib/gitflash/cleanup_spec.rb`.
- **Does not hit:** [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read (through commands) |

## See

- Source: `lib/gitflash/cleanup.rb`, `lib/gitflash/protection.rb`
