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

`gitflash worktree` (alias `wt`). So far only `list`. Code: `WorktreeCli`, `Commands::WorktreeList`.

## Why this shape

Agents use the absolute paths from `wt list --json` and never switch directory. Subcommand style follows `hook` ([[cli]]); `map 'wt' => :worktree` is the alias (`lib/gitflash/cli.rb`).

## Shape

- `wt list`: read only, report `result: { worktrees: [...] }`, JSON command name `worktree list` (`lib/gitflash/commands/worktree_list.rb`).
- Global flags go after the subcommand, as with `hook`: `gitflash wt list --json`.

## Connected to

- **joins:** [[worktrees]], [[json-schema]] `worktree_list_result`, [[command-runner]]
- **looks-like-but-is-not:** `git worktree list`

## If you change this

- **Hits:** [[json-schema]] (command enum plus block), `spec/lib/gitflash/cli_worktree_spec.rb`.
- **Does not hit:** [[delete]], [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read |

## See

- Source: `lib/gitflash/worktree_cli.rb`, `lib/gitflash/commands/worktree_list.rb`
