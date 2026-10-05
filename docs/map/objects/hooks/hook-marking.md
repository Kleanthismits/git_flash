---
type: object
cluster: hooks
universe: live
status: verified
entity: lib/gitflash/hook/branch_marker.rb
verified_on: 2026-10-05
verified_at: 32527f0
---

# Hook marking

Marks the branches an agent creates with plain git as agent work. Code: `Hook::BranchMarker`, `Hook::Creations`, run by the PostToolUse path of [[hook-claude]].

## Why this shape

`clean --agent` needs to know which branches agents made. A PreToolUse hook runs before the branch exists (a failed command would leave a stale mark that a human's later branch of the same name inherits), so marking happens after the command. Claude Code runs PostToolUse only when the Bash command succeeded.

## Shape

- `Creations.for(subcommand, args)` returns the branch name: `checkout -b/-B`, `switch -c/-C/--create`, `branch NAME [START]` (not with delete, rename, copy, list or upstream flags), `worktree add -b/-B NAME`, or `worktree add PATH` alone (branch named after the directory). `worktree add PATH COMMIT`, `--detach` and `--orphan` create none (`lib/gitflash/hook/creations.rb`).
- `CommandParser#creations(line)` gives `{ dir:, branch: }` per git command, following `cd` and `git -C`.
- `BranchMarker#call(command, cwd)` marks a branch only when it is unmarked and its oldest reflog entry starts with `branch: Created from` and is at most 120 seconds old. A branch that was already there, or one with a mark (human or agent), is never touched. With the reflog off nothing is marked.
- Output to Claude: `additionalContext` naming the marked branches and `gitflash mark BRANCH --owner human` to change it.

## Connected to

- **joins:** [[ownership]] (`mark`), [[hook-claude]], [[hook-rules]] (`CommandParser`), [[hook-install]] (registers the PostToolUse entry), [[mark]] (the manual way)
- **looks-like-but-is-not:** `wt add`, which marks while creating

## If you change this

- **Hits:** `clean --agent` selection through [[ownership]]; the PostToolUse entry written by [[hook-install]].
- **Does not hit:** [[snapshot-store]], PreToolUse snapshots.
- **Outside-in:** Claude Code's PostToolUse input (`hook_event_name`, `tool_input.command`, `cwd`) and `hookSpecificOutput.additionalContext`; PostToolUse not firing on non-zero exits is assumed, and the reflog check is the second guard.

## Surfaces

| Surface | Role |
|---|---|
| Claude Code | calls after each Bash command |

## See

- Source: `lib/gitflash/hook/branch_marker.rb`, `lib/gitflash/hook/creations.rb`
