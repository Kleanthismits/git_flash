---
type: object
cluster: commands
universe: live
status: verified
entity: lib/gitflash/commands/worktree_list.rb
verified_on: 2026-10-05
verified_at: 5fc049d
---

# Worktree commands

`gitflash worktree` (alias `wt`): `list`, `add`, `remove`, `lock`, `unlock`, `move`, `prune`, `clean`. Code: `WorktreeCli`, `Commands::WorktreeList`, `WorktreeAdd`, `WorktreeRemove`, `WorktreeLock` (+ `WorktreeUnlock`), `WorktreeMove`, `WorktreePrune`, `WorktreeClean` (subclass of `WorktreeRemove`); shared lookup in `WorktreeCommand`.

## Why this shape

Agents use the absolute paths from `wt list --json` and never switch directory. Subcommand style follows `hook` ([[cli]]); `map 'wt' => :worktree` is the alias (`lib/gitflash/cli.rb`).

## Shape

- `wt list`: read only, report `result: { worktrees: [...] }`, JSON command name `worktree list` (`lib/gitflash/commands/worktree_list.rb`).
- `wt add BRANCH`: source is `existing` (local), `remote` (tracks `origin/BRANCH`) or `new` (from HEAD or `--from`). Path from `--path`, else [[config]] `worktree_dir`. A branch created here gets the owner mark (`--owner`, default `agent`; [[ownership]]). Additive: no confirm, no snapshot. Refuses a branch already checked out elsewhere and a non-empty directory.
- `wt remove [WORKTREE...]`: path or branch; menu in a terminal. Refusals (`protected_worktree`): main checkout, current worktree, locked or dirty without `--force`; rule lives in `Worktree#removal_blocker`. Confirms, snapshots each worktree (own HEAD and files), removes. A worktree with an untracked file over 50 MB (`Snapshot#skipped_files`) is not removed and reported under `failed`: undo could not bring that file back. Ignored files are never saved, so the plan lists them (`ignored_count`, first five in `ignored`) and the confirmation prompt and `--dry-run` text warn that they are lost for good; `--yes` is the opt-in (no separate flag). Reporting is the `RemovalReport` mixin. Undo: [[worktree-revival]].
- `wt lock|unlock WORKTREE`: no confirm; second call is a `noop`; main checkout refused. `wt move WORKTREE PATH`: refuses main, current, locked without `--force`; no confirm (move back to reverse). `wt prune`: lists missing, unlocked worktrees, confirms, runs `git worktree prune`; no snapshot (only git's record of a missing directory goes; branches stay).
- `wt clean`: same criteria flags as [[clean]] (`CleanCriteria`), selection by [[cleanup]]; matches that may not go (locked, dirty without `--force`) are listed in `plan.skipped`; branches stay; missing directories are for `prune`. Plan rows add `reasons`. Hook into `WorktreeRemove`: `build_plan`, `plan_row`.
- Lookup by path or branch is `WorktreeCommand#find!` (`unknown_worktree`); main-checkout refusal is `refuse_main!` (`protected_worktree`).
- Global flags go after the subcommand, as with `hook`: `gitflash wt list --json`.

## Connected to

- **joins:** [[worktrees]], [[cleanup]], [[worktree-revival]], [[ownership]], [[config]], [[change-flow]], [[json-schema]] `worktree_list_result`, [[command-runner]]
- **looks-like-but-is-not:** `git worktree list`

## If you change this

- **Hits:** [[json-schema]] (command enum plus block), `spec/lib/gitflash/cli_worktree_spec.rb`, `cli_worktree_manage_spec.rb`.
- **Does not hit:** [[delete]], [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read, write |

## See

- Source: `lib/gitflash/worktree_cli.rb`, `lib/gitflash/commands/worktree_{command,list,add,remove,lock,unlock,move,prune,clean}.rb`
