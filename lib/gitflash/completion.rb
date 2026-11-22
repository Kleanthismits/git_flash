# frozen_string_literal: true

module Gitflash
  # Shell completion scripts for `gitflash completion SHELL`, built from the Thor command tree so
  # a new command or option is completed without editing a script. What an argument or an option
  # value completes comes from its name in the usage (`checkout [BRANCH]`) or its banner (`REF`);
  # branch names are read with plain git, so completing never starts Ruby.
  class Completion
    SHELLS = %w[bash zsh fish].freeze
    HIDDEN = %w[tree].freeze
    TEMPLATES = File.expand_path('completion', __dir__)

    # What a value completes: local branch names, any path, directories, or fixed words (an
    # Array). A name that is not listed completes nothing.
    ARGUMENTS = { 'BRANCH' => :branch, 'SOURCE' => :branch, 'COMMIT' => :branch,
                  'WORKTREE' => :branch, 'PATH' => :path, 'SHELL' => SHELLS }.freeze
    BANNERS = { 'REF' => :branch, 'DIR' => :directory }.freeze

    # `value` is what the option's value completes; `optional` when it may be left out
    # (`clean --stale`), so the next word may be an argument instead
    Option = Data.define(:switches, :description, :takes_value, :optional, :value)
    # `arguments` are what each positional argument completes, in order; `repeats` when the last
    # one may be given more than once (`delete [BRANCH...]`)
    Command = Data.define(:path, :description, :options, :arguments, :repeats)

    def initialize(cli = Cli)
      @cli = cli
    end

    def script(shell)
      unless SHELLS.include?(shell)
        raise Thor::Error, "Unknown shell '#{shell}'. Choose one of: #{SHELLS.join(', ')}"
      end

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

    # Switches whose next word is their value, so it is not read as a command or an argument
    def value_switches
      options = global_options + commands.flat_map(&:options)
      options.select(&:takes_value).flat_map(&:switches).uniq
    end

    private

    def visible(klass)
      klass.all_commands.reject { |name, command| HIDDEN.include?(name) || command.hidden? }
    end

    def build(path, command)
      words = command.usage.split.drop(1)
      Command.new(path:, description: command.description.to_s,
                  options: command.options.values.map { |option| option_record(option) },
                  arguments: words.map { |word| ARGUMENTS[word.delete('[].')] },
                  repeats: words.last.to_s.end_with?('...', '...]'))
    end

    def option_record(option)
      Option.new(switches: switches(option), description: option.description.to_s,
                 takes_value: !option.boolean?, optional: !option.lazy_default.nil?,
                 value: option.enum || BANNERS[option.banner])
    end

    # A boolean option that defaults to true is also turned off with --no-<name>
    def switches(option)
      if option.boolean? && option.default == true
        negated = "--no-#{option.switch_name.delete_prefix('--')}"
      end
      [option.switch_name, *option.aliases, negated].compact
    end
  end
end
