# frozen_string_literal: true

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
      # guessed: the shell decides the directory (`cd "$REPO"`), so dir is only a fallback
      Target = Data.define(:dir, :command, :scope, :branches, :guessed) do
        # One target for all the commands of a group that run in dir
        def self.merge(dir, group)
          new(dir: dir, command: group.map(&:command).join(' && '),
              scope: group.flat_map(&:scope).uniq, branches: merged_branches(group),
              guessed: group.any?(&:guessed))
        end

        # A target that saves branches without naming them saves every branch, so the merge
        # does too: naming the others' branches would drop the ones it could not name
        def self.merged_branches(group)
          all = group.any? { |target| target.scope.include?('branches') && target.branches.empty? }
          all ? [] : group.flat_map(&:branches).uniq
        end
      end

      SHELLS = %w[bash sh zsh dash ksh].freeze
      MAX_NESTING = 3
      # Subcommands git never lets an alias replace and that have no rule, so their aliases need
      # not be read
      BUILTINS = (Rules::RULES.keys + %w[status log diff show add commit push pull fetch rev-parse
                                         config ls-files remote describe blame grep tag init
                                         clone mv]).freeze

      DIR_COMMANDS = %w[cd pushd popd].freeze

      # `aliases` returns the git aliases configured for a directory, as { name => value }
      def initialize(cwd, aliases: GitInvocation.method(:configured_aliases))
        @cwd = cwd
        @aliases = aliases
        @alias_cache = {}
        @invocation = GitInvocation.new(dir_after: method(:change_dir),
                                        aliases: method(:aliases_in))
      end

      # Git commands that can lose work, with what to save before them
      def targets(command_line)
        git_commands(command_line).filter_map do |git|
          rule = Rules.for(git.subcommand, git.args, git.dir)
          next unless rule

          dir = rule.fetch(:dir, git.dir)
          Target.new(dir: dir.to_s, command: git.command, scope: rule[:scope],
                     branches: rule[:branches] || [], guessed: Paths.guessed?(dir))
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

      def git_commands(command_line, dir = @cwd, depth = 0)
        ShellText.segments(command_line).flat_map do |segment|
          words = CommandWords.new(segment)
          if DIR_COMMANDS.include?(words.words.first)
            dir = dir_after(words.words, dir)
            next substituted(segment, dir, depth)
          end
          substituted(segment, dir, depth) + in_segment(words, dir, segment.strip, depth)
        end
      end

      # `cd DIR` and `pushd DIR` move; `popd` goes back to a directory the text does not show
      def dir_after(words, dir)
        words.first == 'popd' ? @cwd : change_dir(words[1] || Dir.home, dir)
      end

      def in_segment(words, dir, segment, depth)
        return [] if words.words.empty?

        dir = change_dir(words.chdir, dir) if words.chdir
        commands_in(words.words, dir, segment, depth, words.env)
      end

      # Git commands inside `$(...)`, `<(...)` and backticks, which the shell runs first
      def substituted(command_line, dir, depth)
        ShellText.substitutions(command_line).flat_map do |script|
          nested(script, dir, depth)
        end
      end

      # The git commands of a script inside this one. Past the nesting limit a script that
      # mentions git counts as risky without being read, so deep nesting cannot hide a command.
      def nested(script, dir, depth)
        return git_commands(script, dir, depth + 1) if depth < MAX_NESTING
        return [] unless script.match?(/\bgit\b/)

        [GitCommand.new(dir: dir, command: script.strip, subcommand: Rules::UNREAD, args: [])]
      end

      # The git command of one segment, or the ones inside `bash -c "..."`, `eval "..."`,
      # `find -exec` and `!` aliases
      def commands_in(words, dir, segment, depth, env = {})
        words = Wrappers.find_exec(words) || words
        git = File.basename(words.first.to_s) == 'git'
        return git_command(words, dir, segment, depth, env) if git

        script = nested_script(words)
        script ? nested(script, dir, depth) : []
      end

      # The script text passed to a shell (`bash -c`, `sh -lc`) or to `eval`
      def nested_script(words)
        return words.drop(1).join(' ') if words.first == 'eval'
        return nil unless SHELLS.include?(File.basename(words.first))

        index = words.index { |word| word.match?(/\A-[a-z]*c[a-z]*\z/) }
        index && words[index + 1]
      end

      # The directory after `cd PATH` or `git -C PATH`. A path the shell decides when it runs
      # (`cd "$(git rev-parse --show-toplevel)"`, `cd "$REPO"`, `cd -`) falls back to the
      # directory Claude runs in: a snapshot there is better than none.
      def change_dir(path, dir)
        Paths.change_dir(path, dir, @cwd)
      end

      def git_command(words, dir, command, depth, env)
        git = @invocation.parse(words, dir, env)
        return nested(git.script, git.dir, depth) if git.script

        [GitCommand.new(dir: git.dir, command: command, subcommand: git.subcommand, args: git.args)]
      end

      def aliases_in(dir)
        @alias_cache[dir] ||= @aliases.call(dir)
      end
    end
  end
end
