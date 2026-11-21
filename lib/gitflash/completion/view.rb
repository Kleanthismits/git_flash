# frozen_string_literal: true

require 'erb'

module Gitflash
  class Completion
    # What the templates in this directory read: the command tree in the shapes the scripts
    # need, and quoting for each shell. Every script works out the command being completed the
    # same way: the first word that is not an option (or an option's value), plus the second one
    # when the first names a group (`hook`, `skill`, `worktree`/`wt`).
    class View
      BRANCHES = "git for-each-ref --format='%(refname:lstrip=2)' refs/heads 2>/dev/null"

      def initialize(tree)
        @tree = tree
      end

      def render(template)
        ERB.new(File.read(template), trim_mode: '-').result(binding)
      end

      def children(group = '') = @tree.children(group)
      def groups = @tree.groups
      def aliases = @tree.aliases
      def global_options = @tree.global_options

      def value_switches
        @tree.value_switches
      end

      # Commands that have options of their own
      def commands_with_options
        @tree.commands.reject { |command| command.options.empty? }
      end

      # [command path, switch, values] for every option that takes fixed values
      def enum_options
        @tree.commands.flat_map do |command|
          command.options.reject { |option| option.values.empty? }.flat_map do |option|
            option.switches.map { |switch| [command.path, switch, option.values] }
          end
        end
      end

      # Paths of the commands whose arguments are branch names, as a shell case pattern
      def branch_pattern
        @tree.commands.select(&:branches).map { |command| "'#{command.path}'" }.join('|')
      end

      def commands_with_words
        @tree.commands.select { |command| command.words.any? }
      end

      def commands
        @tree.commands
      end

      def switches(options)
        options.flat_map(&:switches).join(' ')
      end

      def names(entries)
        entries.map(&:first).join(' ')
      end

      # zsh `_describe` entries: 'name:description'
      def described_options(options)
        options.flat_map { |option| option.switches.map { |switch| [switch, option.description] } }
               .then { |entries| described(entries) }
      end

      def described(entries)
        entries.map { |name, text| sh_quote("#{name}:#{text}") }.join(' ')
      end

      def sh_quote(text)
        "'#{text.gsub("'") { "'\\''" }}'"
      end

      def fish_quote(text)
        "'#{text.gsub(/[\\']/) { |char| "\\#{char}" }}'"
      end

      # The condition that limits a fish completion to one command path
      def fish_at(path)
        "-n '__gitflash_at #{path.include?(' ') ? "\"#{path}\"" : path}'"
      end

      # `-l json -s y -x -a 'a b' -d '...'` for one option
      def fish_option(option)
        flags = option.switches.map { |switch| fish_flag(switch) }
        flags << fish_value(option) if option.takes_value
        flags << "-d #{fish_quote(option.description)}" unless option.description.empty?
        flags.join(' ')
      end

      def fish_flag(switch)
        switch.start_with?('--') ? "-l #{switch.delete_prefix('--')}" : "-s #{switch[1..]}"
      end

      # Fixed values, else any value (`-r`)
      def fish_value(option)
        option.values.any? ? "-x -a #{fish_quote(option.values.join(' '))}" : '-r'
      end
    end
  end
end
