## [0.1.0.alpha] - 2023-06-17

- Initial release

## [0.1.1.alpha] - 2023-10-28

- Fix delete method
- Added and updated test
- bug fixes

## [0.1.2.alpha] - 2023-11-4

- Refactors and code improvements
- Zeitwerk warning suppress
- Update README
- Bug fixes

## [0.2.0.alpha] - 2023-12-9

- Add reset command
- Code improvements

## [0.3.0] - 2025-10-10

- Fix reset method
- Update to Ruby version 3.3.2
- Bug fixes

## [0.4.0] - 2026-09-24

- Run git commands without a shell and raise on failure
- List branches with `git for-each-ref`; detached HEAD no longer shows as a branch
- List the latest 100 commits for `reset`, unaffected by `log.decorate`
- Exit with an error when a git command fails or outside a git repository
- `delete` does nothing when no branches are available or selected
- `reset --hard` prints `Exited` when declined; fix single-commit message
- Correct `reset` help text
- Portable `bin/gitflash` shebang
- Require thor >= 1.4 (CVE-2025-54314) and Ruby >= 3.3
- Add `version` command (`--version`, `-v`)
- CI: pin third-party action to a commit SHA, restrict token permissions, test Ruby 3.3–3.4

## [0.5.0] - 2026-10-03

- Add `branches` command with last commit, upstream (ahead, behind, gone) and merge status, filters `--merged`, `--gone`, `--stale DAYS`
- Commands accept arguments: `checkout BRANCH`, `delete BRANCH...`, `reset COMMIT`
- Add `--json`, `--yes` and `--dry-run` options to every command
- Never wait for input without a terminal: exit with code 2 and explain what to pass
- `delete` keeps unmerged branches unless `--force` is given (breaking: it used to always force-delete) and also protects the default branch
- Detect the default branch from `origin/HEAD`, falling back to `main` or `master`
- Add `reset --soft`
- JSON contract version 1: every `--json` run prints one envelope (`schema`, `command`, `ok`, `status`, `dry_run`, `plan`, `result`, `error`) defined in `schema/v1.json`; stable error codes
- Results include what is needed to revert: deleted branch SHAs, the previous branch after `checkout`, the previous commit after `reset`
- Add `schema` command that prints the JSON Schema
- Internal: new `Repo` service layer with `Branch` and `Commit` records; integration specs run against real temporary git repositories

## [0.5.1] - 2026-10-04

Security fixes for names and text that come from the repository:

- `checkout` uses `git switch --` and refuses a branch name that starts with a dash. A local ref named like `--force` (for example from a cloned repository) used to become a `git checkout --force` option and discard uncommitted changes
- Branch and default-branch detection use full ref names. A tag named like `origin/<default>` could change the short name of `origin/HEAD`, so the default branch lost its deletion protection and its merge status; `origin/HEAD` must now point inside `refs/remotes/origin/`
- `delete` passes `--` before the branch name; `resolve_commit` refuses references that start with a dash
- Text output shows terminal control characters of repository-controlled text (commit subjects, git errors) as escapes such as `\x1B`, so a crafted commit subject cannot move the cursor, rewrite output or set the clipboard (OSC 52). JSON output keeps the original text

## [0.6.0] - 2026-10-05

- Snapshots: gitflash saves branches, HEAD, tracked, staged and untracked files and stash entries before every change it makes, as git objects under `refs/gitflash/snapshots/` (the working tree is never touched; untracked files over 50 MB are skipped)
- Add `undo [SNAPSHOT]`: restores the parts a snapshot saved (the latest by default), after saving the current state so the undo can be undone
- Add `snapshot` (save on request, `--scope`, `--message`), `snapshots` (list) and `gc --older-than DAYS`
- Every `done` result of `checkout`, `delete` and `reset` includes `undo` with the snapshot id; human output ends with `Undo with: gitflash undo ID`
- Add `hook claude`: a Claude Code `PreToolUse` hook that saves a snapshot before destructive git commands an agent runs itself (`reset`, `checkout -- .`, `restore`, `clean -f`, `branch -D`, `stash drop`, `rebase`, `worktree remove --force`, ...). Modes: `snapshot` (default), `ask`, `deny`. It never blocks a command because of its own errors
- Add `hook install [--scope local|project|user] [--mode ...]` to register the hook in Claude Code settings; it reports which sessions the file applies to, and the local scope uses the main checkout's root inside a worktree, as Claude Code does
- Add `hook status` to show whether the hook protects Claude Code sessions in the current directory
- JSON schema: new `undo` field, commands `undo`, `snapshots`, `snapshot`, `gc`, `hook`, error codes `unknown_snapshot`, `wrong_worktree`, `invalid_settings`

## [0.7.0.beta1] - 2026-10-07

Beta of the parallel agent work release. Install with `gem install gitflash --pre`. The JSON contract of the new commands may still change before 0.7.0. Needs git 2.36 or newer.

- Settings: `.gitflash.yml` in the repository and `~/.config/gitflash.yml` (the repository file wins) with `protected` branch patterns, `stale_days` and `worktree_dir`. Unknown keys, wrong types, duplicate keys and unreadable files fail with the new error code `invalid_config`
- Ownership marks: `branch.<name>.gitflash-owner` (`agent` or `human`) in git config, shown as `owner` in `branches` and `worktree list`. Add `mark [BRANCH...] [--owner agent|human] [--clear]` to set it
- Add `worktree` (alias `wt`): `list`, `add`, `remove`, `clean`, `prune`, `lock`, `unlock` and `move`. `wt list --json` gives absolute paths, dirty state, ahead and behind, merge status, lock state and owner. `wt add` marks the branches it creates as agent work. `wt remove` and `wt clean` save a snapshot first and refuse the main checkout, the current worktree, and locked or dirty worktrees unless `--force`. `undo` adds a removed worktree back with its branch and uncommitted files. Ignored files are not saved: the plan lists them before they are deleted. A worktree with an untracked file over 50 MB is not removed
- Add `clean`: deletes merged branches and branches whose upstream is gone, and with `--stale [DAYS]` and `--agent` stale and agent-created ones, with a snapshot first. Each chosen branch lists why. Unmerged branches need `--force`
- `clean` and `delete` never touch the current and default branch, `main`, `master`, `protected` branches or branches checked out in a worktree
- Add `pick SOURCE [SHA...]`: `--list` shows the commits of SOURCE that are not on the current branch (already applied patches are marked), `SHA...` applies them oldest first with `git cherry-pick -x` after a snapshot, and on a conflict it stops and lists the files. `pick --continue`, `--skip` and `--abort` wrap git's own controls
- The Claude Code hook also runs after Bash commands (`PostToolUse`): branches created with plain git (`checkout -b`, `switch -c`, `branch NAME`, `worktree add`) are marked as agent work. `hook install` adds it, so run it again after upgrading; `hook status` reports whether marking is on. A gitflash hook under a matcher that does not cover Bash no longer counts as installed
- JSON schema: new commands `clean`, `mark`, `pick` and `worktree ...`, error codes `invalid_config`, `unknown_worktree`, `protected_worktree` and `conflict`, the `owner` field, and `recreate_worktree` in the `undo` plan
- Author names from other branches are shown with control characters escaped in `pick` output

## [Unreleased]

- `pick` without a source branch shows a list of the other local branches in a terminal, as `checkout` does; without a terminal the source is still required
