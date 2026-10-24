# frozen_string_literal: true

module Gitflash
  module Hook
    # Which git subcommands can lose work git cannot restore, and what to save before them.
    # Each rule takes the subcommand's arguments and the directory, and returns nil (safe) or
    # { scope:, branches:, dir: } where branches may contain :current for the checked-out one.
    module Rules
      FULL = %w[branches head worktree].freeze
      # A command too deeply nested to read (see CommandParser#nested): save everything
      UNREAD = :unread

      module_function

      def for(subcommand, args, dir)
        # No branch names: the snapshot keeps every branch
        return { scope: FULL } if subcommand == UNREAD

        rule = RULES[subcommand]
        rule&.call(args, dir)
      end

      def any?(args, flags)
        args.intersect?(flags)
      end

      # `git checkout PATH` overwrites uncommitted changes in PATH without any flag, and telling a
      # path from a branch needs git; an argument that names an existing file counts as a path.
      def checkout(args, dir)
        discards = any?(args, %w[-- . --force --patch --ours --theirs]) ||
                   short_flags(args).match?(/[fp]/) || path_arg?(args, dir)
        discards ? { scope: %w[worktree] } : nil
      end

      # The letters of all short options, so bundled ones such as `-fq` are seen
      def short_flags(args)
        args.select { |arg| arg.start_with?('-') && !arg.start_with?('--') }.join
      end

      def path_arg?(args, dir)
        args.reject { |arg| arg.start_with?('-') }.any? do |arg|
          File.exist?(Paths.expand(arg, dir))
        end
      end

      # `git clean` without -f removes files too when clean.requireForce is false
      def clean(args, dir)
        flags = args.select { |arg| arg.start_with?('-') }
        short = short_flags(args)
        removes = any?(flags, %w[--force --interactive]) || short.match?(/[fi]/) ||
                  !require_force?(dir)
        dry_run = flags.include?('--dry-run') || short.include?('n')
        return nil unless removes && !dry_run

        # -x and -X delete ignored files too
        { scope: %w[worktree], ignored: short.match?(/[xX]/) }
      end

      def require_force?(dir)
        stdout, _stderr, success = Git::BashCommand.capture('git', '-C', dir, 'config', '--bool',
                                                            'clean.requireForce')
        !(success && stdout.strip == 'false')
      end

      def switch(args, _dir)
        discards = any?(args, %w[--force --discard-changes]) || short_flags(args).include?('f')
        discards ? { scope: %w[head worktree] } : nil
      end

      def stash(args, _dir)
        case args.first
        when 'drop', 'clear' then { scope: %w[stashes] }
        when 'pop' then { scope: %w[worktree stashes] }
        end
      end

      def branch(args, _dir)
        changes = any?(args, %w[--delete --force --move --copy]) ||
                  short_flags(args).match?(/[dDfmMcC]/)
        return nil unless changes

        names = args.reject { |arg| arg.start_with?('-') }
        # A name the shell or xargs fills in (`$b`, `{}`) is unknown: save every branch
        names = [] if names.any? { |name| Paths.unresolved?(name) || name.include?('{}') }
        { scope: %w[branches], branches: names }
      end

      def update_ref(args, _dir)
        # `--stdin` reads the refs to delete from input the text does not show: save all branches
        return { scope: %w[branches] } if args.include?('--stdin')
        return nil unless args.include?('-d')

        heads = args.select { |arg| arg.start_with?('refs/heads/') }
        { scope: %w[branches], branches: heads.map { |ref| ref.delete_prefix('refs/heads/') } }
      end

      def rebase(args, _dir)
        args.include?('--continue') ? nil : { scope: FULL, branches: [:current] }
      end

      def abort(args, _dir)
        any?(args, %w[--abort --quit]) ? { scope: %w[worktree] } : nil
      end

      # `git worktree remove PATH` deletes that worktree's ignored files, and with --force its
      # uncommitted ones too
      def worktree(args, dir)
        return nil unless args.first == 'remove'

        path = args[1..].reject { |arg| arg.start_with?('-') }.first
        path && { scope: %w[worktree], dir: Paths.change_dir(path, dir, dir), ignored: true }
      end

      RULES = {
        'reset' => ->(_args, _dir) { { scope: FULL, branches: [:current] } },
        'checkout' => method(:checkout),
        'restore' => ->(_args, _dir) { { scope: %w[worktree] } },
        'clean' => method(:clean),
        'switch' => method(:switch),
        'stash' => method(:stash),
        'branch' => method(:branch),
        'update-ref' => method(:update_ref),
        'rebase' => method(:rebase),
        'merge' => method(:abort),
        'cherry-pick' => method(:abort),
        'revert' => method(:abort),
        'am' => method(:abort),
        'worktree' => method(:worktree)
      }.merge(HistoryRules::RULES).freeze
    end
  end
end
