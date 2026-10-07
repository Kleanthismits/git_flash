# frozen_string_literal: true

require 'shellwords'

module Gitflash
  module Hook
    # Finds git commands in a shell command line that can lose work git itself cannot restore:
    # uncommitted or untracked files, deleted branches (their reflog is deleted with them) and
    # dropped stashes. Commands that only add history (commit, merge, pull) are ignored because
    # the reflog already covers them. See Rules for the list.
    #
    # The parser is deliberately simple: it splits on ; & | and newlines outside quotes, follows
    # `cd DIR` and `git -C DIR`, and may report a command more often than needed. An extra
    # snapshot is harmless; a missed one is not.
    class CommandParser
      # dir: where to take the snapshot; branches: names, or :current for the checked-out one
      Target = Data.define(:dir, :command, :scope, :branches)

      PREFIXES = %w[sudo command exec time nohup env].freeze
      OPTIONS_WITH_VALUE = %w[-c --git-dir --work-tree --namespace --exec-path --config-env].freeze

      def initialize(cwd)
        @cwd = cwd
      end

      # Git commands that can lose work, with what to save before them
      def targets(command_line)
        git_commands(command_line).filter_map do |git|
          rule = Rules.for(git.subcommand, git.args, git.dir)
          next unless rule

          Target.new(dir: rule.fetch(:dir, git.dir), command: git.command, scope: rule[:scope],
                     branches: rule[:branches] || [])
        end
      end

      # Branches that git commands in the line create, as { dir:, branch: }
      def creations(command_line)
        git_commands(command_line).filter_map do |git|
          branch = Creations.for(git.subcommand, git.args)
          { dir: git.dir, branch: branch } if branch
        end
      end

      private

      # A git command found in the line: the directory it runs in (after `cd` and `-C`), the
      # subcommand and its arguments
      GitCommand = Data.define(:dir, :command, :subcommand, :args)

      def git_commands(command_line)
        dir = @cwd
        segments(command_line).filter_map do |segment|
          words = words(segment)
          next if words.empty?

          if words.first == 'cd'
            dir = File.expand_path(words[1] || Dir.home, dir)
            next
          end
          git_command(words, dir, segment.strip) if File.basename(words.first) == 'git'
        end
      end

      # Splits on unquoted ; & | and newlines
      def segments(line)
        parts = [+'']
        quote = nil
        line.each_char do |char|
          if quote
            quote = nil if char == quote
          elsif ["'", '"'].include?(char)
            quote = char
          elsif ";&|\n".include?(char)
            parts << +''
            next
          end
          parts.last << char
        end
        parts.reject { |part| part.strip.empty? }
      end

      # Shell words without subshell brackets, environment assignments and wrappers like sudo
      def words(segment)
        words = split(segment).map { |word| unwrap(word) }.reject(&:empty?)
        words.shift while words.first && prefix?(words.first)
        words
      end

      def prefix?(word)
        PREFIXES.include?(word) || word.match?(/\A\w+=/)
      end

      def split(segment)
        Shellwords.split(segment)
      rescue ArgumentError
        segment.split
      end

      def unwrap(word)
        word.delete_prefix('(').delete_prefix('{').delete_suffix(')').delete_suffix('}')
      end

      def git_command(words, dir, command)
        index, dir = skip_git_options(words, dir)
        GitCommand.new(dir: dir, command: command, subcommand: words[index],
                       args: words[(index + 1)..] || [])
      end

      # Index of the subcommand, and the directory after any -C options
      def skip_git_options(words, dir)
        index = 1
        while (option = words[index])&.start_with?('-')
          dir = File.expand_path(words[index + 1].to_s, dir) if option == '-C'
          index += option == '-C' || OPTIONS_WITH_VALUE.include?(option) ? 2 : 1
        end
        [index, dir]
      end
    end
  end
end
