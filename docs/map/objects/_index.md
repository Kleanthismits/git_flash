# Objects

Format: `slug`: what it is. Status. Source. All verified 2026-10-03 at `dde88fd`.

## contract
- `json-schema`: versioned JSON output contract. verified. `schema/v1.json`
- `exit-codes`: 0 ok, 1 error, 2 usage or confirmation needed. verified. `lib/gitflash/{error,usage_error,confirmation_required}.rb`
- `ui-output`: text and JSON reporting, `undo` field. verified. `lib/gitflash/ui.rb`
- `command-descriptions`: help text per command. verified. `command_descriptions.yml`, `lib/gitflash/configuration.rb`

## core
- `repo`: branches, commits, HEAD through git. verified. `lib/gitflash/repo.rb`
- `branch`: branch record. verified. `lib/gitflash/branch.rb`
- `commit`: commit record. verified. `lib/gitflash/commit.rb`
- `config`: settings files `.gitflash.yml`, `~/.config/gitflash.yml`. verified. `lib/gitflash/{config,config_keys}.rb`
- `worktrees`: worktree records from git. verified. `lib/gitflash/{worktrees,worktree}.rb`
- `ownership`: agent/human mark per branch in git config. verified. `lib/gitflash/ownership.rb`
- `cleanup`: pure selection rules and branch protection. verified. `lib/gitflash/{cleanup,protection}.rb`
- `cherry-pick`: git access for pick (candidates, apply, progress). verified. `lib/gitflash/cherry_pick.rb`
- `bash-command`: git process runner. verified. `lib/gitflash/git/bash_command.rb`
- `command-runner`: runs one command, maps errors to exit. verified. `lib/gitflash/command_runner.rb`

## commands
- `cli`: Thor entry, global flags, hook subcommand. verified. `lib/gitflash/cli.rb`
- `branches`: list, filter merged/gone/stale. verified. `lib/gitflash/commands/branches.rb`
- `checkout`: switch branch, HEAD snapshot. verified. `lib/gitflash/commands/checkout.rb`
- `pick`: cherry-pick from another branch, list, control flags. verified. `lib/gitflash/commands/{pick,pick_control,pick_outcome}.rb`
- `mark`: set or clear agent/human owner of branches. verified. `lib/gitflash/commands/mark.rb`
- `clean`: delete merged/gone/stale/agent branches, subclass of delete. verified. `lib/gitflash/commands/{clean,clean_criteria}.rb`
- `delete`: remove branches, confirm, snapshot. verified. `lib/gitflash/commands/delete.rb`
- `reset`: reset to commit, snapshot every mode. verified. `lib/gitflash/commands/reset.rb`
- `undo`: restore a snapshot, undo-able. verified. `lib/gitflash/commands/undo.rb`
- `worktree-commands`: `worktree`/`wt` list, add, remove, lock, unlock, move, prune. verified. `lib/gitflash/{worktree_cli,commands/worktree_list}.rb`
- `snapshot-commands`: snapshot, snapshots, gc. verified. `lib/gitflash/commands/{snapshot_create,snapshot_list,gc}.rb`
- `change-flow`: plan, confirm, snapshot, execute, report. verified. `lib/gitflash/commands/base.rb`

## snapshots
- `worktree-revival`: undo of a removed worktree. verified. `lib/gitflash/{worktree_revival,git/in_directory}.rb`
- `snapshot`: saved-state record. verified. `lib/gitflash/snapshot.rb`
- `snapshot-store`: create/list/delete under `refs/gitflash/snapshots/`. verified. `lib/gitflash/snapshots.rb`
- `state-capture`: read state, write git objects. verified. `lib/gitflash/state_capture.rb`
- `restore`: plan and apply a restore. verified. `lib/gitflash/restore.rb`

## hooks
- `hook-claude`: Claude Code PreToolUse hook. verified. `lib/gitflash/hook/claude.rb`, `lib/gitflash/hook_cli.rb`
- `hook-rules`: dangerous-command rules and parser. verified. `lib/gitflash/hook/{rules,command_parser}.rb`
- `hook-install`: settings install and status. verified. `lib/gitflash/hook/settings.rb`, `lib/gitflash/commands/hook_{install,status}.rb`
