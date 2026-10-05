---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/pick.rb
verified_on: 2026-10-05
verified_at: 39cf49c
---

# Pick command

Cherry-pick commits from another branch. Code: `Commands::Pick` (list and apply), `Commands::PickControl` (`--continue`, `--skip`, `--abort`), `PickOutcome` mixin; git access in [[cherry-pick]].

## Why this shape

Moving fixes between agent branches needs a list of what is missing, a safe apply, and a way out of conflicts. Same guarded flow as other changes (plan, confirm, snapshot, report), so `undo` returns to the start.

## Shape

- `pick SOURCE --list`: commits of SOURCE (local or remote-tracking branch) not on HEAD, oldest first, merges left out; `status` `new` or `applied` (an equivalent patch is already here, from `--cherry-mark`). Result `pick_list_result`.
- `pick SOURCE SHA...`: SHAs may be 4+ character prefixes; applied in source order whatever the argument order; already-applied ones go to `plan.skipped`; nothing new gives `noop`. Without SHAs a menu in a terminal. Always `-x`; `--no-commit` stages only.
- Snapshot scope `branches` (current branch), `head`, `worktree`, taken after confirm (`pick.rb`). `undo` is in the envelope.
- Conflict: `git cherry-pick` stops, status `failed`, exit 1, error code `conflict`, result lists `conflicted` files, `current`, `remaining`, `applied`. A new pick is refused while one is in progress (`invalid_usage`).
- `PickControl`: exactly one of the three flags (`invalid_options` otherwise); `--skip` and `--abort` confirm and snapshot (`head`, `worktree`), `--continue` does neither. All three use `GIT_EDITOR=true` so git never opens an editor. `Pick.command_for(options)` picks the class in [[cli]].

## Connected to

- **owns:** [[cherry-pick]]
- **joins:** [[change-flow]], [[json-schema]] `pick_*`, [[exit-codes]] (`conflict`), [[snapshot-store]], [[repo]] (`resolve_commit`, `current_branch`)
- **looks-like-but-is-not:** `git cherry-pick` itself (this one lists, snapshots and reports JSON)

## If you change this

- **Hits:** [[json-schema]] `pick_plan` / `pick_result`; `spec/lib/gitflash/cli_pick_spec.rb`; agents using `--list --json` then `SHA... --yes --json`.
- **Does not hit:** [[delete]], [[reset]], [[worktree-commands]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read (`--list`), write |

## See

- Source: `lib/gitflash/commands/pick.rb`, `pick_control.rb`, `pick_outcome.rb`
