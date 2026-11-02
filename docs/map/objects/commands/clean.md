---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/clean.rb
verified_on: 2026-11-01
verified_at: b55b61e plus unused-branch rule
---

# Clean command

Delete branches that are no longer needed. Code: `Commands::Clean`, a subclass of [[delete]]. `wt clean` is the worktree twin: see [[worktree-commands]].

## Why this shape

Same guarded flow as `delete` (plan, confirm, snapshot, report), so `undo` and the JSON contract stay the same. Only the choice of branches is new, and it lives in [[cleanup]] as a pure function.

## Shape

- Criteria flags `--merged --gone --stale [DAYS] --agent`; none given = merged + gone. `--stale` without a number uses `stale_days` from [[config]]. Flag handling is the `CleanCriteria` mixin, shared with `wt clean` (`lib/gitflash/commands/clean_criteria.rb`).
- With an `origin` remote but no `origin/HEAD`, the plan (also the no-op plan) carries `warning` and the confirmation text a `Note:` (`Clean#warning`, `default_branch_guessed?`): merged is judged against a guessed local main/master; the fix is `git remote set-head origin --auto`.
- Protection: current, default, `main`, `master`, `develop`, `development`, `trunk`, `release/*` (`Protection::NAMES` / `PATTERNS`), `protected` patterns, any branch checked out in a worktree ([[cleanup]] `Protection`).
- Unmerged matches are kept (listed in `plan.skipped`) unless `--force`; `delete`'s `-d` / `-D` rule.
- Unused branches (no commits since creation) are not chosen by `--merged` / `--agent`, even with `--force`; listed in `plan.skipped` ([[cleanup]] `held_back`). `--stale` removes them.
- Plan adds `reasons` (per branch) and `skipped` to the `delete` plan; result is `delete_result`. Hooks into `Delete`: `build_plan`.
- Nothing chosen: status `noop` with the plan.

## Connected to

- **owns:** [[cleanup]]
- **joins:** [[delete]], [[config]], [[ownership]], [[worktrees]], [[change-flow]], [[json-schema]] `clean_plan`
- **looks-like-but-is-not:** `git clean` (files, not branches)

## If you change this

- **Hits:** [[delete]] hook methods; [[json-schema]] `clean_plan`; `wt clean` through `CleanCriteria`.
- **Does not hit:** [[reset]], [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | write |

## See

- Source: `lib/gitflash/commands/clean.rb`, `lib/gitflash/commands/clean_criteria.rb`
