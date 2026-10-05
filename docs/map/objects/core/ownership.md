---
type: object
cluster: core
universe: live
status: verified
entity: lib/gitflash/ownership.rb
verified_on: 2026-10-05
verified_at: 15af952
---

# Ownership

Mark of who created a branch: `agent` or `human`. Code: `Ownership`. Stored in git config as `branch.<name>.gitflash-owner`.

## Why this shape

Cleanup must tell agent branches from human work. git config needs no extra files, is shared by all worktrees, and git deletes the `branch.<name>` section when the branch is deleted, so marks do not outlive branches.

## Shape

- `all` (one `git config --get-regexp -z`), `annotate(branches)`, `mark(branch, owner)`, `clear(branch)` (`lib/gitflash/ownership.rb`). Branch names may contain dots; the key is parsed by prefix and suffix.
- Unmarked = human. Nothing unmarked is ever selected for automatic cleanup.
- [[repo]] `branches` sets `Branch#owner` through `annotate`; [[worktrees]] copies it to `Worktree#owner`.
- Not restored by `undo`: a branch recreated by undo has no mark until set again.
- Setters: `wt add` marks `agent` for branches it creates, and [[mark]] sets or clears any branch. Marking from the Claude hook is not built: the hook runs before the command, so the branch does not exist yet (a `PostToolUse` hook would be needed).

## Connected to

- **joins:** [[repo]], [[branch]] (`owner`), [[worktrees]], [[json-schema]] (`branch.owner`, `worktree.owner`)
- **looks-like-but-is-not:** git `branch.<name>.*` keys git itself writes (remote, merge)

## If you change this

- **Hits:** the config key name (existing marks in user repos orphaned); `branches` and `wt list` output; later `clean`.
- **Does not hit:** [[snapshot-store]].

## Surfaces

| Surface | Role |
|---|---|
| agents, humans | read (`owner` field and `agent` label) |

## See

- Source: `lib/gitflash/ownership.rb`
