# GitFlash

[![GitHub version](https://badge.fury.io/gh/Kleanthismits%2Fgit_flash.svg)](https://badge.fury.io/gh/Kleanthismits%2Fgit_flash)

⚠️ **This project is still under development**: Use at your own risk!

A safety net and cleanup tool for git repositories that AI coding agents work in. It works on plain git, with nothing new to adopt, and every command can be run by a person in a terminal or by an agent with a stable JSON contract.

See [docs/ROADMAP.md](docs/ROADMAP.md) for where the project is going.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gitflash'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install gitflash

## Requirements

This gem requires Ruby 3.3+ and git.

## Usage

Run `gitflash` inside a git repository to get a list with the available commands and their description.

| Command | Description |
| --- | --- |
| `gitflash branches` | List local branches with last commit, upstream status and merge status. Filter with `--merged`, `--gone` or `--stale DAYS` |
| `gitflash checkout [BRANCH]` | Check out a branch, or pick one from a list |
| `gitflash delete [BRANCH...]` | Delete branches, or pick them from a list. The current, default, `main` and `master` branches are protected. Unmerged branches are kept unless you pass `--force` |
| `gitflash reset [COMMIT]` | Reset to a commit, or pick one of the latest 100. Mixed by default; `--soft` keeps changes staged, `--hard` discards them after confirmation |
| `gitflash mark [BRANCH...]` | Mark branches as agent (default) or human work, or `--clear` the mark. Without a branch it marks the current one. Use it for branches made with plain git so `clean --agent` can find them |
| `gitflash clean` | Delete merged branches and branches whose upstream is gone, with a snapshot first. `--stale [DAYS]` and `--agent` add stale and agent-created branches; unmerged ones are kept unless `--force`. Protected: current, default, `main`, `master`, `protected` in `.gitflash.yml`, branches checked out in a worktree |
| `gitflash worktree` (`wt`) `list`, `add`, `remove`, `clean`, `prune`, `lock`, `unlock`, `move` | Worktrees for parallel agent work, with absolute paths in `--json` (see below) |
| `gitflash pick SOURCE [SHA...]` | Cherry-pick commits from another branch: `--list` shows what is missing here, `--continue`, `--skip` and `--abort` handle conflicts |
| `gitflash undo [SNAPSHOT]` | Restore a snapshot, the latest by default: deleted branches, moved branches, HEAD, uncommitted and untracked files, dropped stashes |
| `gitflash snapshot` | Save the current state on request (`--scope`, `--message`) |
| `gitflash snapshots` | List snapshots, newest first |
| `gitflash gc` | Delete snapshots older than 30 days (`--older-than DAYS`) |
| `gitflash hook install` | Protect plain git commands run by Claude Code (see below) |
| `gitflash hook status` | Show whether the hook protects Claude Code sessions in the current directory |
| `gitflash schema` | Print the JSON Schema of the `--json` output |
| `gitflash version` | Print the installed version (also `--version`, `-v`) |

### Parallel agent work

`gitflash wt add feature` creates a worktree (default `../<repo>.worktrees/feature`) and marks a new branch as agent work. For a branch made with plain git, run `gitflash mark` on it (no argument marks the current branch). `gitflash wt list --json` gives every worktree's absolute path, branch, dirty state, ahead/behind, merge status, lock state and owner, so an agent never has to switch directories.

`gitflash wt remove` and `gitflash wt clean` save a snapshot first, and `gitflash undo` adds the worktree back with its branch and uncommitted files. Ignored files (`.env`, `node_modules`) are not saved: the plan lists them before they are deleted. A worktree with an untracked file over 50 MB is not removed.

`gitflash pick other-branch --list` lists the commits missing here (a commit whose patch is already here is marked `=`). `gitflash pick other-branch SHA... --yes` applies them oldest first with `-x`. On a conflict it stops and lists the files; resolve them and run `gitflash pick --continue`, or `--skip` / `--abort`.

Settings live in `.gitflash.yml` in the repository and `~/.config/gitflash.yml` (the repository file wins):

```yaml
protected: ["release/*"]   # branch patterns clean and delete never touch
stale_days: 30             # used by --stale without a number
worktree_dir: "../%<repo>s.worktrees/%<branch>s"
```

### Undo

Before every change it makes, gitflash saves a snapshot: branches, HEAD, tracked, staged and untracked files, and stash entries. Snapshots are plain git objects under `refs/gitflash/snapshots/`; the working tree is never touched while saving. Git's own `revert` and `reflog` cover committed work; snapshots also cover what git never recorded: uncommitted and untracked files, deleted branches (git deletes their reflog) and dropped stashes.

```bash
gitflash delete old-feature --yes
```

```bash
gitflash undo --yes
```

`gitflash undo` restores only what the snapshot saved and what differs, and saves the current state first, so an undo can itself be undone.

### Protect plain git commands run by AI agents

Agents often run git directly. Claude Code's own checkpoints do not cover changes made by shell commands, so a `git reset --hard` or `git clean -fd` run by an agent cannot be rewound there. Install the gitflash hook once per repository:

```bash
gitflash hook install
```

Before Claude Code runs a command that can discard work git cannot restore (`reset`, `checkout -- .`, `restore`, `clean -f`, `branch -D`, `stash drop`, `rebase`, `worktree remove --force`, ...), the hook saves a snapshot and tells the agent how to undo it. Other commands pass through; the hook adds about 0.1 s to commands that do not mention git. `--mode ask` also asks you to approve such commands, `--mode deny` blocks them.

Where the hook goes, following Claude Code's own rules:

| Scope | File | Applies to |
| --- | --- | --- |
| `local` (default) | `.claude/settings.local.json` at the repository root (the main checkout's root inside a worktree) | Sessions anywhere in the repository and its worktrees |
| `project` | `.claude/settings.json` at the repository top level, to share with your team | Sessions started in that directory |
| `user` | `~/.claude/settings.json` | Every session |

Claude Code reloads settings files, so running sessions pick the hook up without a restart. Run `gitflash hook status` in the directory where you start Claude Code to check which files apply and whether the `gitflash` executable is found.

### Scripts

Without an argument, a command shows an interactive list. With arguments it runs directly, which also works in scripts.

Options for every command:

| Option | Effect |
| --- | --- |
| `--json` | Print JSON instead of text. Never shows lists or prompts |
| `--yes`, `-y` | Skip confirmation prompts |
| `--dry-run` | Show what would happen without changing anything |

Run `gitflash help <command>` for details on a command.

### Scripts and AI agents

Without a terminal (for example in a script, CI or an AI coding agent), gitflash never waits for input:

- A command that needs a list selection fails with exit code 2 and says which argument to pass.
- A destructive action (`delete`, `reset --hard`) fails with exit code 2 and returns the plan unless you pass `--yes`.

With `--json`, every command prints one object in the same envelope, defined in [schema/v1.json](schema/v1.json) (also printed by `gitflash schema`):

```json
{
  "schema": 1,
  "command": "delete",
  "ok": true,
  "status": "done",
  "dry_run": false,
  "plan": { "branches": ["old-feature"], "force": false },
  "result": { "deleted": [{ "branch": "old-feature", "sha": "3551cba" }], "failed": [] }
}
```

- `status`: `done`, `planned` (`--dry-run`), `noop`, `cancelled`, `failed`, `confirmation_required` or `error`. `ok` is true for the first four.
- `result` includes what you need to revert: the SHA of each deleted branch (`git branch NAME SHA`), the previous branch after `checkout`, the previous commit after `reset`.
- `undo` names the snapshot saved before the change and the command that restores it (`gitflash undo ID`).
- `error.code` is a stable identifier such as `unknown_branch`, `protected_branch` or `confirmation_required`.

```bash
gitflash branches --merged --json
```

```bash
gitflash delete old-feature another-branch --yes --json
```

Exit codes: `0` success, `1` a git command failed (for example a branch was not fully merged), `2` invalid usage or confirmation required.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Kleanthismits/git_flash. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Kleanthismits/git_flash/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the GitFlash project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Kleanthismits/git_flash/blob/main/CODE_OF_CONDUCT.md).
