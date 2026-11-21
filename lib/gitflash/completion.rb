# frozen_string_literal: true

module Gitflash
  # Shell completion scripts for `gitflash completion SHELL`, built from the Thor command tree so
  # a new command or option is completed without editing a script. Commands whose arguments name
  # branches or worktrees (BRANCH, SOURCE, COMMIT, WORKTREE in their usage) complete local branch
  # names, read with plain git: completing never starts Ruby.
  class Completion
    SHELLS = %w[bash zsh fish].freeze
    BRANCH_ARGUMENTS = /\[?(BRANCH|SOURCE|COMMIT|WORKTREE)\b/
    HIDDEN = %w[tree].freeze
    TEMPLATES = File.expand_path('completion', __dir__)
    # Fixed words a command's argument takes
    ARGUMENT_WORDS = { 'completion' => SHELLS }.freeze

    Option = Data.define(:switches, :description, :values, :takes_value)
    # `words` are the fixed words its argument takes; `branches` when it takes branch names
    Command = Data.define(:path, :description, :options, :branches, :words)

    def initialize(cli = Cli)
      @cli = cli
    end

    def script(shell)
      raise ArgumentError, "Unknown shell '#{shell}'" unless SHELLS.include?(shell)

      View.new(self).render(File.join(TEMPLATES, "#{shell}.erb"))
    end

    # Words that name a command at the top level or inside a group, with the group aliases
    def groups
      @cli.subcommand_classes.keys
    end

    def aliases
      @cli.map.filter_map { |from, to|
        [from, to.to_s] if !from.start_with?('-') && groups.include?(to.to_s)
      }.to_h
    end

    # Commands at the top level ('') and inside each group ('worktree'), as [name, description]
    def children(group = '')
      klass = group.empty? ? @cli : @cli.subcommand_classes.fetch(group)
      visible(klass).map { |name, command| [name, command.description.to_s] }
    end

    # Every command that runs something, top level and in groups, by its path ('worktree add')
    def commands
      top = visible(@cli).except(*groups).map { |name, cmd| build(name, cmd) }
      top + groups.flat_map do |group|
        visible(@cli.subcommand_classes.fetch(group)).map do |name, cmd|
          build("#{group} #{name}", cmd)
        end
      end
    end

    def global_options
      @cli.class_options.values.map { |option| option_record(option) }
    end

    # Switches whose next word is their value, so it is not read as a command
    def value_switches
      options = global_options + commands.flat_map(&:options)
      options.select(&:takes_value).flat_map(&:switches).uniq
    end

    private

    def visible(klass)
      klass.all_commands.reject { |name, command| HIDDEN.include?(name) || command.hidden? }
    end

    def build(path, command)
      Command.new(path:, description: command.description.to_s,
                  options: command.options.values.map { |option| option_record(option) },
                  branches: command.usage.match?(BRANCH_ARGUMENTS),
                  words: ARGUMENT_WORDS.fetch(path, []))
    end

    def option_record(option)
      switches = [option.switch_name, *option.aliases]
      if option.boolean? && option.default == true
        switches << "--no-#{option.switch_name.delete_prefix('--')}"
      end
      Option.new(switches:, description: option.description.to_s, values: option.enum || [],
                 takes_value: !option.boolean?)
    end
  end
end
