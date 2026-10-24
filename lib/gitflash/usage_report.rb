# frozen_string_literal: true

module Gitflash
  # Prints an error Thor raised while reading the command line (an unknown option, a value
  # outside an enum, a missing argument) as gitflash's own errors are printed: in the JSON
  # envelope with --json, else as text on stderr.
  class UsageReport
    # The command names the JSON envelope knows (schema/v1.json)
    def self.commands
      @commands ||= JSON.parse(File.read(Cli::SCHEMA_PATH)).dig('properties', 'command', 'enum')
    end

    def initialize(args)
      @args = args
    end

    def print(error)
      error = UsageError.new(error.message)
      return Ui.new(command: command, json: true).error(error) if json?

      warn TerminalText.safe(error.message)
    end

    private

    def json?
      @args.include?('--json')
    end

    # The command as the envelope names it: `wt` and `worktree` subcommands as
    # `worktree SUBCOMMAND`, `hook SUBCOMMAND`, else the first word; `gitflash` when the line
    # names no known command
    def command
      words = @args.reject { |arg| arg.start_with?('-') }
      first = words.first.to_s
      first = 'worktree' if first == 'wt'
      name = %w[worktree hook].include?(first) ? [first, words[1]].compact.join(' ') : first
      self.class.commands.include?(name) ? name : 'gitflash'
    end
  end
end
