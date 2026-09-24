# GitFlash

[![Gem Version](https://badge.fury.io/rb/gitflash.svg)](https://badge.fury.io/rb/gitflash)

⚠️ **This project is still under development**: Use at your own risk!

This gem allows you to use some of the most common git commands in a more user intuitive way.

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
| `gitflash checkout` | Select a local branch and check it out |
| `gitflash delete` | Select local branches (excluding the current branch and main/master) and force-delete them |
| `gitflash reset` | Select one of the latest 100 commits and reset to it (mixed reset) |
| `gitflash reset --hard` | Same as `reset`, but discard all current changes after confirmation |
| `gitflash version` | Print the installed version (also `--version`, `-v`) |

Run `gitflash help <command>` for details on a command.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Kleanthismits/git_flash. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Kleanthismits/git_flash/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the GitFlash project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Kleanthismits/git_flash/blob/main/CODE_OF_CONDUCT.md).
