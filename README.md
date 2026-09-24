# GitFlash

[![Gem Version](https://badge.fury.io/rb/gitflash.svg)](https://badge.fury.io/rb/gitflash)

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
| `gitflash schema` | Print the JSON Schema of the `--json` output |
| `gitflash version` | Print the installed version (also `--version`, `-v`) |

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
