# frozen_string_literal: true

require 'erb'

module Gitflash
  class Completion
    # Renders the templates in this directory: `tree` is the Completion they read, and the
    # helpers put it in the shapes the scripts need, quoted for each shell. Every script works
    # out the command being completed the same way: the first word that is not an option (or an
    # option's value), plus the second one when the first names a group (`hook`, `skill`,
    # `worktree`/`wt`). The words after it are its positional arguments, counted from 0.
    class View
      BRANCHES = "git for-each-ref --format='%(refname:lstrip=2)' refs/heads 2>/dev/null"
      # What each shell runs to offer a value that is not fixed words. bash offers nothing but
      # branches: it completes file names itself (`complete -o default`).
      BASH = { branch: '_gitflash_branches "$cur"' }.freeze
      ZSH = { branch: "compadd -- ${(f)\"$(#{BRANCHES})\"}", path: '_files',
              directory: '_files -/' }.freeze
      FISH = { branch: "-a '(__gitflash_branches)'", path: '-F',
               directory: "-a '(__fish_complete_directories)'" }.freeze

      attr_reader :tree

      def initialize(tree)
        @tree = tree
      end

      def render(template)
        ERB.new(File.read(template), trim_mode: '-').result(binding)
      end

      # Commands that have options of their own
      def commands_with_options
        tree.commands.reject { |command| command.options.empty? }
      end

      # [case pattern on "$cmd $prev", value] for every option whose value must follow it: the
      # command's own options first, then the global ones under any command. An option whose
      # value may be left out is not listed, so the word after it completes as an argument.
      def value_cases
        own = tree.commands.flat_map do |command|
          required(command.options).map do |switch, value|
            [sh_quote("#{command.path} #{switch}"), value]
          end
        end
        own + required(tree.global_options).map do |switch, value|
          ["*#{sh_quote(" #{switch}")}", value]
        end
      end

      # [case pattern on "$cmd $n", value] for every positional argument, where n counts the
      # arguments before the one being completed. A repeated last argument is a pattern that
      # matches any n: the patterns of the arguments before it come first, and the first match
      # wins.
      def argument_cases
        tree.commands.flat_map do |command|
          last = command.repeats ? command.arguments.size - 1 : nil
          command.arguments.each_with_index.map do |value, index|
            if index == last then ["#{sh_quote("#{command.path} ")}*", value]
            else [sh_quote("#{command.path} #{index}"), value]
            end
          end
        end
      end

      # [command path, n or "n+", value] for every positional argument that completes something
      def fish_arguments
        tree.commands.flat_map do |command|
          last = command.repeats ? command.arguments.size - 1 : nil
          command.arguments.each_with_index.filter_map do |value, index|
            next unless value

            [command.path, index == last ? "#{index}+" : index.to_s, value]
          end
        end
      end

      # Fixed words are static, from the code, so they may go through compgen -W
      def bash_action(value)
        if value.is_a?(Array)
          "COMPREPLY=($(compgen -W '#{value.join(' ')}' -- \"$cur\"))"
        else
          BASH.fetch(value, ':')
        end
      end

      def zsh_action(value)
        value.is_a?(Array) ? "compadd -- #{value.join(' ')}" : ZSH.fetch(value, ':')
      end

      def fish_values(value)
        value.is_a?(Array) ? "-a #{fish_quote(value.join(' '))}" : FISH[value]
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

      # The condition that limits a fish completion to one command path, and to its argument
      # number n ("1", or "1+" for the first and later ones) when given
      def fish_at(path, argument = nil)
        "-n '__gitflash_at \"#{path}\"#{" #{argument}" if argument}'"
      end

      # `-l json -s y -x -a 'a b' -d '...'` for one option
      def fish_option(option)
        flags = option.switches.map { |switch| fish_flag(switch) }
        flags << fish_value(option) if option.takes_value && !option.optional
        flags << "-d #{fish_quote(option.description)}" unless option.description.empty?
        flags.join(' ')
      end

      private

      def required(options)
        options.select { |option| option.takes_value && !option.optional }
               .flat_map { |option| option.switches.map { |switch| [switch, option.value] } }
      end

      def fish_flag(switch)
        switch.start_with?('--') ? "-l #{switch.delete_prefix('--')}" : "-s #{switch[1..]}"
      end

      # `-x` takes a value and no file names, `-r` a value that may be a file name
      def fish_value(option)
        option.value == :path ? '-r -F' : ['-x', fish_values(option.value)].compact.join(' ')
      end
    end
  end
end
