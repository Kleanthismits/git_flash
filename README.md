# gitflash

[![Gem Version](https://img.shields.io/gem/v/gitflash)](https://rubygems.org/gems/gitflash)
[![RSpec](https://github.com/Kleanthismits/git_flash/actions/workflows/rspec.yml/badge.svg)](https://github.com/Kleanthismits/git_flash/actions/workflows/rspec.yml)

**A safety net and cleanup tool for git repositories that AI coding agents work in.**

gitflash works on plain git, with nothing new to adopt. Every command can be run by a person in a terminal or by an agent through one stable JSON contract. (Not to be confused with git-flow, the branching model.)

> **Status: pre-1.0.** Command flags may still change between minor versions. The JSON contract ([schema v1](https://github.com/Kleanthismits/git_flash/blob/main/schema/v1.json)) is versioned and stable. See the [roadmap](https://github.com/Kleanthismits/git_flash/blob/main/docs/ROADMAP.md) for where the project is going.

## Why

An agent runs `git reset --hard` or `git clean -fd` from the shell. Claude Code's checkpoints do not track shell commands, and git never recorded the uncommitted and untracked files, so that work is gone. With gitflash:

```bash
gitflash hook install   # once per repository

# Later, Claude Code runs a destructive command such as `git reset --hard HEAD~3`.
# The hook saves a snapshot first and tells the agent how to undo it.

gitflash undo --yes     # HEAD, branches, uncommitted and untracked files come back
```

To see it happen without an agent, run [`demo/agent-undo.sh`](https://github.com/Kleanthismits/git_flash/blob/main/demo/agent-undo.sh) from a checkout. It works in a throwaway repository and feeds the hook the same input Claude Code sends.

<details>
<summary>See it run</summary>

```text
== A repository with uncommitted work
$ git status --short
 M app.rb
?? notes.txt

== The agent is about to run: git reset --hard && git clean -fd
$ <Claude Code hook input> | gitflash hook claude
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "gitflash saved snapshot 20261102T094036000992-f633 before `git reset --hard && git clean -fd`. If this discards work that was still needed, restore it with `gitflash undo 20261102T094036000992-f633` (list snapshots with `gitflash snapshots`)."
  }
}

== The command runs. Git alone cannot get this work back
$ git reset --hard && git clean -fd
HEAD is now at 1313e78 Initial commit
Removing notes.txt
$ git status --short
$ cat app.rb
puts "hello"

== gitflash undo restores the snapshot the hook saved
$ gitflash undo --yes
Restored snapshot 20261102T094036000992-f633:
* restore tracked, staged and untracked files
Undo with: gitflash undo 20261102T094037415717-1342
$ git status --short
 M app.rb
?? notes.txt
$ cat app.rb notes.txt
puts "hello, world"
API_URL=http://localhost:3000

Uncommitted edit and untracked file are back.
```

</details>

gitflash also cleans up after parallel agent work: it knows which branches and worktrees agents created, and removes the merged, gone and stale ones with a snapshot first.

## Installation

```bash
gem install gitflash
```

Requires Ruby 3.3+ and git 2.36+ (the worktree commands read `git worktree list -z`).

Prerelease versions (named like `0.7.0.beta3`) are only installed when you ask for them: `gem install gitflash --pre`, or the exact version in a Gemfile.

## Quick start for agents

Pick one. Details for each are in [Agent integrations](https://github.com/Kleanthismits/git_flash/blob/main/docs/agent-integrations.md).

| Way | Command | You get |
| --- | --- | --- |
| Claude Code plugin | `/plugin marketplace add Kleanthismits/git_flash`, then `/plugin install gitflash@gitflash` | Hook, MCP server and skill in one install (gem 0.8.0 or newer; for now the 0.8.0.beta1 prerelease: `gem install gitflash --pre`) |
| Hook and skill | `gitflash hook install` and `gitflash skill install` | Snapshots before destructive plain git commands; the agent learns to prefer gitflash |
| MCP server | `claude mcp add gitflash -- gitflash mcp` | gitflash as MCP tools, with your approval before destructive changes |

Do not combine the plugin with `gitflash hook install`, or the hook runs twice.

## Commands

Run `gitflash` inside a git repository for the list, and `gitflash help <command>` for the flags of one command. Without arguments, most commands show an interactive list.

| Command | What it does |
| --- | --- |
| `gitflash branches` | List local branches with last commit, upstream and merge status (`--merged`, `--gone`, `--stale DAYS`) |
| `gitflash checkout [BRANCH]` | Check out a branch, or pick one from a list |
| `gitflash delete [BRANCH...]` | Delete branches; protected and unmerged branches are kept unless `--force` |
| `gitflash reset [COMMIT]` | Reset to a commit (mixed by default, `--soft`, `--hard` after confirmation) |
| `gitflash clean` | Delete merged branches and branches whose upstream is gone (`--stale [DAYS]`, `--agent` for agent-created ones) |
| `gitflash mark [BRANCH...]` | Mark branches as agent or human work, so `clean --agent` finds branches made with plain git |
| `gitflash worktree` (`wt`) | `list`, `add`, `remove`, `clean`, `prune`, `lock`, `unlock`, `move` worktrees for parallel agent work |
| `gitflash pick [SOURCE] [SHA...]` | Cherry-pick commits from another branch (`--list`, `--continue`, `--skip`, `--abort`) |
| `gitflash undo [SNAPSHOT]` | Restore a snapshot, by default the latest one taken in this worktree |
| `gitflash snapshot` | Save the current state on request (`--scope`, `--message`) |
| `gitflash snapshots` | List snapshots, newest first |
| `gitflash gc` | Delete snapshots older than 30 days (`--older-than DAYS`) |
| `gitflash hook install`, `hook status` | Protect plain git commands run by Claude Code, and check where the hook applies |
| `gitflash skill install`, `skill show` | Install or print the gitflash Agent Skill |
| `gitflash mcp` | Run an MCP server for the current repository on stdio |
| `gitflash schema` | Print the JSON Schema of the `--json` output |
| `gitflash version` | Print the installed version (also `--version`, `-v`) |

## Undo

Before every change it makes, gitflash saves a snapshot: branches, HEAD, tracked, staged and untracked files, and stash entries. Snapshots are plain git objects under `refs/gitflash/snapshots/`; the working tree is never touched while saving.

Git's own `revert` and `reflog` cover committed work. Snapshots also cover what git never recorded: uncommitted and untracked files, deleted branches (git deletes their reflog) and dropped stashes.

```bash
gitflash delete old-feature --yes
```

```bash
gitflash undo --yes
```

`gitflash undo` restores only what the snapshot saved and what differs, and saves the current state first, so an undo can itself be undone.

> [!WARNING]
> Snapshots copy untracked files that are not ignored, including a stray secret, into git objects. A `git push --mirror` or a `refs/*` refspec would publish them. Ignore such files or list them in `snapshot_exclude`; see [Configuration](https://github.com/Kleanthismits/git_flash/blob/main/docs/configuration.md#snapshots-and-secrets).

## Parallel agent work

`gitflash wt add feature` creates a worktree (default `../<repo>.worktrees/feature`) and marks its new branch as agent work. `gitflash wt list --json` gives every worktree's absolute path, branch, dirty state, ahead/behind, merge status, lock state and owner, so an agent never has to switch directories.

For a branch made with plain git, run `gitflash mark` on it (no argument marks the current branch). The owner defaults to `human` when stdin is a terminal and `agent` otherwise, so a script run from a terminal should pass `--owner agent`.

`gitflash wt remove` and `gitflash wt clean` save a snapshot first, and `gitflash undo` adds the worktree back with its branch and uncommitted files. Ignored files (`.env`, `node_modules`) are not saved: the plan lists them, and removing a worktree that has some needs `--confirm TOKEN` instead of `--yes`. A worktree with an untracked file over 50 MB is not removed.

`gitflash clean` keeps a branch nobody has committed to since it was created (it only looks merged); `--stale` removes it once it has been unused that long. Protected branches and branches checked out in a worktree are never touched.

`gitflash pick other-branch --list` lists the commits missing here (a commit whose patch is already here is marked `=`). `gitflash pick other-branch SHA... --yes` applies them oldest first with `-x`. On a conflict it stops and lists the files; resolve them and run `gitflash pick --continue`, or `--skip` / `--abort`.

## Scripts and agents

Every command takes `--json`, `--yes` and `--dry-run`. Without a terminal, gitflash never waits for input: a missing argument or an unconfirmed destructive change fails with exit code 2 and returns the plan.

```bash
gitflash delete old-feature --yes --json
```

Every `--json` answer uses one envelope with `status`, `plan`, `result`, `undo` and a stable `error.code`. Exit codes are `0` success, `1` a git command failed, `2` invalid usage or confirmation required. The full contract is in [JSON contract](https://github.com/Kleanthismits/git_flash/blob/main/docs/json-contract.md).

## Configuration

Optional settings live in `.gitflash.yml` in the repository and `~/.config/gitflash.yml`: extra protected branch patterns, the default for `--stale`, where worktrees go, and files snapshots never copy. See [Configuration](https://github.com/Kleanthismits/git_flash/blob/main/docs/configuration.md).

## How it compares

| Tool | Difference |
| --- | --- |
| jj (Jujutsu) | Has an operation log and `jj undo`, but you adopt a new version control tool |
| GitButler | Has an MCP server and Claude Code hooks, but needs the GitButler app and its branch model |
| `mcp-server-git` and other git MCP servers | Give agents git actions, but no undo for what the agent changed |
| Claude Code checkpoints | Undo Claude's file edits, but not changes made through shell commands |

gitflash adds undo for plain git, for the operations agent tools do not track, with nothing new to adopt.

## Development

After checking out the repository, run `bin/setup` to install dependencies. Then run `bundle exec rake spec` for the tests and `bundle exec rubocop` for the linter. `bin/console` opens an interactive prompt.

To install the gem from your checkout, run `bundle exec rake install`.

To release, bump the version in `lib/gitflash/version.rb` and `.claude-plugin/plugin.json` (a spec checks they match), move the `[Unreleased]` notes in `CHANGELOG.md` under the new version, and run `bundle exec rake release`. It tags the version, pushes the tag and publishes the gem to [rubygems.org](https://rubygems.org/gems/gitflash).

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/Kleanthismits/git_flash/issues). Everyone interacting in the project is expected to follow the [code of conduct](https://github.com/Kleanthismits/git_flash/blob/main/CODE_OF_CONDUCT.md).

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
