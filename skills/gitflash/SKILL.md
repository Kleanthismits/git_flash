---
name: gitflash
description: Safe branch, worktree and cleanup work in git repositories, with an undo for every change. Use when you are about to delete or reset branches, discard local changes, remove worktrees, clean up merged or agent-created branches, move commits between branches, or need to recover work that a git command lost (a deleted branch, uncommitted or untracked files, a dropped stash).
---

# gitflash

gitflash is a command-line tool for git repositories that agents work in. Before every change it makes, it saves a snapshot (branches, HEAD, staged, tracked and untracked files, stash entries), so `gitflash undo` can bring the previous state back. Plain git cannot restore uncommitted or untracked files, the reflog of a deleted branch, or a dropped stash.

Check that it is installed with `gitflash version`. It needs a git repository; run it from inside one.

## Rules

If the gitflash MCP tools are available (`list_branches`, `delete_branches`, ...), you may use them instead of the shell: they answer with the same envelope. To see a plan without changing anything, call `plan_change` with the tool name and its arguments; then call the tool with `confirm_token`. Destructive tools may ask the user to approve the plan in the client: `cancelled` means the user declined, so do not retry. Otherwise they return `confirmation_required` with `error.confirm_token` first; call again with `confirm_token` only after the user agreed to the plan.

1. Prefer gitflash over plain git for anything that deletes or rewrites: `gitflash delete` over `git branch -D`, `gitflash reset --hard` over `git reset --hard`, `gitflash wt remove` over `git worktree remove`.
2. Always pass `--json`. Never parse the text output.
3. Without a terminal gitflash never waits for input. A command that needs a choice fails with exit code 2 and says which argument to pass.
4. Use the two-step flow for changes: run the command without `--yes` (or with `--dry-run`) to get the plan, check it, then run it again with `--yes`.
5. Do not pass `--yes` to commands the user did not ask for. Show the plan and ask when the change is larger than the request.
6. After a change, keep the `undo.command` from the output. Tell the user how to undo it.

## The JSON envelope

Every `--json` run prints one object (the full JSON Schema: `gitflash schema`):

```json
{
  "schema": 1,
  "command": "delete",
  "ok": true,
  "status": "done",
  "dry_run": false,
  "plan": { "branches": ["old-feature"], "force": false },
  "result": { "deleted": [{ "branch": "old-feature", "sha": "3551cba" }], "failed": [] },
  "undo": { "snapshot": "20261031T191914339710-b836", "command": "gitflash undo 20261031T191914339710-b836" }
}
```

- `status`: `done`, `planned` (`--dry-run`), `noop` (nothing to do), `cancelled`, `failed`, `confirmation_required` or `error`. `ok` is true for the first four.
- `plan`: what the command will do or did. `result`: what happened, including what you need to revert by hand (the SHA of each deleted branch, the previous branch after `checkout`, the previous commit after `reset`).
- `undo`: the snapshot saved before the change and the command that restores it. With `"reused": true` the id is an earlier snapshot, because nothing had changed since it was taken; that is not a missing snapshot, and undo with it restores the state before this change.
- `error.code`: a stable identifier to branch on, for example `unknown_branch`, `protected_branch`, `confirmation_required`, `conflict`, `invalid_config`. The message is for people.

Exit codes: `0` success, `1` an error (for example a git command failed), `2` invalid usage or a confirmation is needed.

## Confirmation

- `status: confirmation_required` with exit code 2 means the command stopped before changing anything. The `plan` shows what it would do. Run it again with `--yes` when the plan is what you want.
- Some changes cannot be undone by `gitflash undo`: `gc` (deletes snapshots), `wt remove` and `wt clean` of a worktree with ignored files (`.env`, local databases), and `skill install` over a changed skill file. `--yes` is not enough for them. The error has `confirm_token`; run the same command again with `--confirm TOKEN`. The token belongs to that exact plan. Ask the user before you do this.

## Commands

Every command accepts `--json`, `--yes` (`-y`), `--dry-run` and `--confirm TOKEN`. Run `gitflash help COMMAND` for details.

| Task | Command |
| --- | --- |
| List branches with upstream and merge status | `gitflash branches --json` (filters: `--merged`, `--gone`, `--stale DAYS`) |
| Switch branch | `gitflash checkout BRANCH --json` |
| Delete branches | `gitflash delete BRANCH... --yes --json` (unmerged ones need `--force`) |
| Reset the current branch | `gitflash reset COMMIT --json` (mixed; `--soft`, `--hard`) |
| Delete merged and upstream-gone branches | `gitflash clean --json` (add `--stale [DAYS]`, `--agent`; `--force` for unmerged ones) |
| Mark branches as agent or human work | `gitflash mark BRANCH... --owner agent --json` (`--clear` removes the mark) |
| List worktrees with absolute paths | `gitflash wt list --json` |
| Create a worktree for parallel work | `gitflash wt add BRANCH --json` (the path is in `result`) |
| Remove worktrees | `gitflash wt remove WORKTREE... --yes --json`, `gitflash wt clean --yes --json` |
| Other worktree commands | `gitflash wt prune`, `lock`, `unlock`, `move` |
| Commits of another branch that are not here | `gitflash pick SOURCE --list --json` |
| Apply them | `gitflash pick SOURCE SHA... --yes --json` (on `conflict`: resolve, then `pick --continue`, or `--skip`, `--abort`) |
| Save the current state | `gitflash snapshot --message WHY --json` |
| List snapshots | `gitflash snapshots --json` |
| Restore a snapshot | `gitflash undo [SNAPSHOT] --yes --json` (default: the latest one taken in this worktree) |
| Delete old snapshots | `gitflash gc --older-than DAYS --json` (needs `--confirm TOKEN`) |

## Protected branches

`delete` and `clean` never touch the current branch, the default branch, `main`, `master`, `develop`, `development`, `trunk`, `release/*`, the `protected` patterns in `.gitflash.yml` and `~/.config/gitflash.yml`, or (for `clean`) a branch checked out in a worktree. Do not try to work around this with plain git; ask the user.

## Parallel agent work

- Create each agent's worktree with `gitflash wt add BRANCH`. Work in the absolute path from `result.path`. `gitflash wt list --json` shows every worktree's path, branch, dirty state and owner from any of them.
- `wt add` marks a new branch as agent work. For a branch you made with plain git, run `gitflash mark BRANCH --owner agent`, so `gitflash clean --agent` can find it later.
- `gitflash undo` without an ID restores the latest snapshot of the current worktree, not one taken by another agent in a parallel worktree. Pass the ID from `undo.command` to be exact.

## Recovering lost work

When the user says a git command lost something:

1. Run `gitflash snapshots --json` and find the snapshot taken before the loss (`created_at`, `reason`).
2. Run `gitflash undo SNAPSHOT --dry-run --json` and show the user what it restores.
3. Run `gitflash undo SNAPSHOT --yes --json`. The current state is saved first, so this undo can itself be undone.

Snapshots do not save ignored files or untracked files over 50 MB, and they cannot bring back a branch on a remote after `git push --force`.
