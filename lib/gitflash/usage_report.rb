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

    # Thor takes `--json` and `--json=true` alike
    def json?
      @args.intersect?(%w[--json --json=true])
    end

    # The command as the envelope names it: `wt` and `worktree` subcommands as
    # `worktree SUBCOMMAND`, `hook SUBCOMMAND`, else the first word; `gitflash` when the line
    # names no known command
    def command
      words = @args.reject { |arg| arg.start_with?('-') }
      first = resolve(Cli, words.first.to_s)
      first = 'worktree' if first == 'wt'
      name = case first
             when 'worktree' then "worktree #{resolve(WorktreeCli, words[1].to_s)}"
             when 'hook' then "hook #{resolve(HookCli, words[1].to_s)}"
             else first
             end
      self.class.commands.include?(name) ? name : 'gitflash'
    end

    # The command Thor runs for a word: itself, or the one command it is an unambiguous prefix
    # of (Thor runs `mar` as `mark`)
    def resolve(klass, word)
      names = klass.all_commands.keys.map { |key| key.tr('_', '-') }
      return word if names.include?(word)

      matches = names.select { |key| key.start_with?(word) }
      matches.one? && !word.empty? ? matches.first : word
    end
  end
end
