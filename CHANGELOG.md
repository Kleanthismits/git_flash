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

## [0.7.0.beta2] - 2026-10-08

Second beta of the parallel agent work release: the `pick` branch list, a quieter `hook claude` and a round of security fixes on top of beta1. Install with `gem install gitflash --pre`. If you installed the hook before, run `gitflash hook install` again. Needs git 2.36 or newer.

- `pick` without a source branch shows a list of the other local branches in a terminal, as `checkout` does; without a terminal the source is still required
- `hook claude` is no longer listed in `gitflash hook` help (it is run by Claude Code, not by hand; `gitflash hook help claude` still describes it) and prints a short note instead of waiting for input when run in a terminal. The `hook` line in `gitflash help` now says it installs and checks the Claude Code hooks
- Security hardening, from a CodeRabbit scan of the repository:
  - Snapshots save untracked files whose names look like Git pathspec magic (`:(exclude)*`) or start or end with a space; before, such a name could drop other files from the snapshot. `Repo#toplevel` and the git readers keep whitespace at the end of a path
  - Confirmation prompts show control characters in paths as escapes, as other output does
  - `protected` branch patterns of the user file and the repository file add up; a repository can protect more branches but can no longer remove the ones the user protects
  - `worktree_dir` may only use `%<repo>s` and `%<branch>s` and is limited to 512 characters (anything else is `invalid_config`); a format width such as `%<repo>999999999s` could exhaust memory
  - `pick --continue --dry-run` only shows the plan
  - `pick` reads `git log -z` with one field per line, so a commit message cannot forge entries in the list, and only commits found by `git rev-list` are offered
  - The git runner never hands a lone string to a shell
  - The Claude hook in `ask` mode asks also when no snapshot could be saved, notices bundled branch flags (`git branch -qD x`), `git clean -i`, and commands inside `bash -c`, `sh -c` and `eval`, and marks a branch as agent work only if it did not exist before the command
  - `hook install` refuses to write `.claude` settings through a symbolic link in the repository (the user scope may be a link)
  - `docs/map/_meta/check.rb` and `sync-twins.sh` do not follow links, read files over 2 MB, or print raw file names
  - Output keeps a path from the repository on one line: a newline or tab in a worktree path is shown as an escape, so it cannot forge a row in the confirmation text, the list or the menus. `Repo#toplevel` and the git readers remove only git's final newline, not a carriage return that ends the path
  - When a command touches several directories the hook tells Claude one `gitflash undo` command per snapshot; a failure to record branches never stops the snapshot; the record directory is refused unless it is a real directory only the user can use
  - A literal backslash in a path is shown doubled, so a path with a newline and a path with the characters backslash and n stay two different choices in the `wt remove` menu
  - The hook marks a branch the command deleted and created again (`git branch -D x && git switch -c x`) as agent work: the record keeps a branch's creation stamp, not only its name

## [0.7.0.beta3] - 2026-10-25

Third beta of the parallel agent work release: the fixes of a security review of the repository (issues #34 to #54), each reviewed before merging. Install with `gem install gitflash --pre`. Needs git 2.36 or newer.

Some behaviour changes, so check scripts and agent instructions that call gitflash:

- `gc`, and `wt remove` / `wt clean` of a worktree with ignored files, are no longer confirmed by `--yes`: pass `--confirm TOKEN` with the token the refusal names
- `gc --older-than` takes a whole number of days, 1 or more
- `mark` without `--owner` marks the branch as `human` when stdin is a terminal
- `clean` and `delete` also protect `develop`, `development`, `trunk` and `release/*`
- A repository's `worktree_dir` must stay next to the repository; set other places in `~/.config/gitflash.yml`
- Usage errors exit with 2 and, with `--json`, print the JSON envelope

The changes:

- The Claude hook no longer lets a command through when it fails in `ask` or `deny` mode: an error now asks the user or blocks the command, with the reason. A snapshot that fails no longer stops `ask` mode from asking, and `cd ~unknownuser` or `git -C ~unknownuser` no longer makes the hook fail (#34)
- The Claude hook snapshots the directory Claude runs in when a `cd` or `git -C` path is decided by the shell (`cd "$(git rev-parse --show-toplevel)"`, `cd "$REPO"`, `cd -`); before, it looked for a directory with that literal name and saved nothing. It says that directory was a guess and may not be the repository the command changes, and it tells the agent about every risky command it could not snapshot, in snapshot mode too, instead of staying silent (#35)
- The Claude hook sees git commands inside shell syntax: after `if`, `then`, `do`, `while`, `!` and the like, inside `$(...)`, `<(...)` and backticks, and after a quote escaped with a backslash (`echo "a\"b"; git reset --hard`). Quotes are followed as the shell does, and a command nested deeper than three levels counts as risky instead of being skipped. Before, `deny` mode let these through and snapshot mode saved nothing (#36)
- The Claude hook sees git behind wrappers with options (`sudo -u me`, `env -i`, `/usr/bin/env`, `timeout 5`, `nice -n 5`, `xargs`, `find -exec`), expands git aliases (`-c alias.x=...` and the repository's `alias.*`, including `!` aliases), snapshots the repository that `--work-tree`, `--git-dir`, `GIT_WORK_TREE` or `GIT_DIR` names, follows `pushd`, and no longer takes a redirection such as `> out` for a branch name. When a command deletes branches it does not name, the snapshot keeps every branch instead of none (#37)
- The Claude hook snapshots before more commands that lose work: `git rm -f`, `git checkout-index -f`, `git read-tree -u --reset`, `git reflog expire` and `delete`, `git gc --prune=now`, `git prune`, `git push . :branch`, `git update-ref --stdin`, `git worktree remove` without `--force` (it still deletes ignored files), and `git clean` without `-f` when `clean.requireForce` is false (#38)
- `gc --older-than` takes a whole number of days, 1 or more. Before, `0` or a negative value selected every snapshot, including the newest, and a fraction such as `0.5` selected snapshots older than that part of a day (#39)
- `hook install` keeps the installed mode when run without `--mode`; before, running it again (as the upgrade note says) silently turned `ask` or `deny` back into `snapshot`. A weaker `--mode` now needs `--downgrade`, and the result reports `mode` and `previous_mode` (#40)
- The Claude hook no longer suggests that `gitflash undo` brings everything back: for `git clean -x`/`-X` and `git worktree remove` it names the ignored files that will be deleted (no snapshot saves them), and it names untracked files over 50 MB that a snapshot left out (#41)
- `--yes` no longer confirms a change `gitflash undo` cannot revert. `gc` (which deletes snapshots) now fails with `confirmation_required` and a `confirm_token` in the error; re-run with `--confirm TOKEN` to make that exact change, or type the token in a terminal. The token is made from the plan, so it never confirms a different change (#42)
- `wt remove` and `wt clean` no longer delete ignored files (`.env`, local databases) on `--yes` alone: when a chosen worktree has ignored files, which no snapshot saves, confirming needs `--confirm TOKEN`, as for `gc` (#43)
- `undo` without an ID restores the latest snapshot taken in the current worktree, not the newest one in the repository, which can belong to another agent working in a parallel worktree. The plan shows the snapshot's `reason` (#44)
- `clean` and `delete` also protect `develop`, `development`, `trunk` and `release/*`, so a git-flow `develop` merged into `main` is no longer deleted. When the repository has a remote but no `origin/HEAD`, `clean` warns that the default branch was guessed (#45)
- `--json` prints the envelope for every error of the commands that use it (all but `schema` and `version`, which print their own output). An unexpected error is reported as `failed` (exit 1) instead of a stack trace. A bad option or unknown command is `invalid_usage` with exit 2, as the README says, instead of Thor's text and exit 1. A damaged snapshot ref is skipped with a warning instead of breaking every command that takes a snapshot. Settings whose root is not an object, or that cannot be read, are `invalid_settings`. A path with an unknown `~user` is a usage error (#46)
- Snapshots read from refs are checked before use: one whose ref name does not match its id, or that holds a commit id that is not a full SHA, an invalid branch name or a relative worktree path, is skipped with a warning. Snapshots are ordered by the time they were taken, not by ref name, so a planted ref cannot become the default for `undo` (#48)
- A worktree argument that is one worktree's path and another worktree's branch is refused as ambiguous instead of picking whichever is listed first (#52)
- `mark` without `--owner` marks the branch as `human` when stdin is a terminal and as `agent` otherwise (agents and scripts without a terminal; a script run from a terminal should pass `--owner agent`). Before, a person running `gitflash mark` to claim a branch marked it as agent work, which `clean --agent --force` deletes (#50)
- A repository's `.gitflash.yml` can no longer place worktrees anywhere on disk: its `worktree_dir` must be a relative path that stays next to the repository (no absolute path, `~` or climbing above the repository's parent), and `worktree_dir` in `~/.config/gitflash.yml` now wins over the repository's (#47)
- New `snapshot_exclude` setting: untracked files whose path or name matches (for example `*.pem`, `.env*`) are never copied into snapshots, and are listed as `excluded_files`. The README now explains that snapshots copy every untracked file that is not ignored into git objects (#49)
- `protected` patterns accept `{a,b}` alternatives, and a pattern that could never match a branch (a space at either end, a control character, `~`, `^`, `:` or `\`, `..` outside a `{a,b}` alternative, or an empty one) is `invalid_config` instead of silently protecting nothing (#51)
- `hook install` writes the settings file in one step (a temporary file renamed into place), keeps its permissions and a dotfiles link, and refuses a `hooks` value it cannot add to. A crash while writing can no longer leave a broken settings file that Claude Code would ignore, together with your permission rules (#53)
- CI: every GitHub Action is pinned to a commit SHA, checkout no longer keeps the token in the git config, and Dependabot proposes updates to the pins (#54)

## [0.7.0] - 2026-10-31

The parallel agent work release: settings, ownership marks, `worktree`, `clean` and `pick`, with every change from 0.7.0.beta1, beta2 and beta3 above. No changes since 0.7.0.beta3. The JSON contract of the new commands is now stable. Needs git 2.36 or newer.

Upgrading from 0.6.0:

- Run `gitflash hook install` again, so the hook also marks branches created with plain git (`PostToolUse`). It keeps the installed mode
- Check scripts and agent instructions against the behaviour changes listed under 0.7.0.beta3: `--confirm TOKEN` for `gc` and for removing worktrees with ignored files, `delete` and `clean` protecting `develop`, `trunk` and `release/*`, `mark` defaulting to `human` in a terminal, and usage errors exiting with 2

## [Unreleased]

- Add the gitflash Agent Skill (`skills/gitflash/SKILL.md`, shipped in the gem): when to use gitflash instead of plain git, the `--json` envelope, the plan then `--yes` flow, `--confirm` tokens, the commands and how to recover lost work with `undo`
- Add `skill install`: copies the skill to `~/.claude/skills/gitflash/` (default, `--scope user`), to `.claude/skills/gitflash/` in the repository (`--scope project`) or to `DIR/gitflash/` (`--path DIR`). Replacing a file that differs from the shipped skill needs `--confirm TOKEN`; the project scope refuses symbolic links
- Add `skill show`, which prints the skill
- JSON schema: new command `skill install` with the `skill_install` plan and result
- Add `mcp`: an MCP server on stdio (official `mcp` gem, loaded only by this command) for the repository in the current directory. Read-only tools `list_branches`, `list_worktrees`, `list_pickable_commits`, `list_snapshots`; tools that lose nothing `add_worktree`, `cherry_pick_commits`, `cherry_pick_control`, `mark_branches`, `save_snapshot`; destructive tools `delete_branches`, `clean_branches`, `reset_branch`, `remove_worktrees`, `move_worktree`, `undo`. Every tool answers with the JSON envelope. A destructive tool's first call returns the plan and `error.confirm_token`; a second call with `confirm_token` (valid 5 minutes, bound to the arguments and the plan) makes the change
- `mcp` asks the user to approve a destructive tool's plan through the client when it supports elicitation, runs the change when they approve and answers `cancelled` when they decline. Without an answer within 2 minutes, an error, or with `--no-elicitation`, the token flow is used
- New runtime dependency: `mcp` (~> 1.8)
- `mcp` starts outside a git repository too; its tools then answer with `not_a_repository`
- Claude Code plugin (`.claude-plugin/`): the hook (snapshot mode), the MCP server and the skill in one install with `/plugin marketplace add Kleanthismits/git_flash` and `/plugin install gitflash@gitflash`. It needs the gitflash gem
