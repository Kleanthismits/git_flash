# frozen_string_literal: true

module Gitflash
  module Hook
    # Which git commands create a branch, and the name of it: `checkout -b`, `switch -c`,
    # `branch NAME` and `worktree add -b` (or a path without a commit, which names the branch
    # after the directory). Returns the name, or nil when the command creates no branch.
    module Creations
      NOT_CREATING = %w[
        -d -D --delete -m -M --move -c -C --copy -u --set-upstream-to --unset-upstream
        --edit-description --list -a --all -r --remotes -v -vv --verbose --show-current --contains
        --no-contains --merged --no-merged --points-at
      ].freeze
      WORKTREE_VALUE_OPTIONS = %w[-b -B --reason --orphan].freeze

      module_function

      def for(subcommand, args)
        case subcommand
        when 'checkout' then flagged(args, %w[-b -B])
        when 'switch' then flagged(args, %w[-c -C --create --force-create])
        when 'branch' then plain_branch(args)
        when 'worktree' then worktree(args)
        end
      end

      # The value of the first of `flags`: `-b NAME`, `-bNAME` or `--create=NAME`
      def flagged(args, flags)
        args.each_with_index do |arg, index|
          return args[index + 1] if flags.include?(arg) && args[index + 1]

          value = attached_value(arg, flags)
          return value if value
        end
        nil
      end

      def attached_value(arg, flags)
        flags.each do |flag|
          if flag.start_with?('--')
            return arg.delete_prefix("#{flag}=") if arg.start_with?("#{flag}=")
          elsif arg.start_with?(flag) && arg.length > flag.length && !arg.start_with?('--')
            return arg.delete_prefix(flag)
          end
        end
        nil
      end

      # `git branch NAME [START]` creates NAME; listing, deleting or renaming flags mean it does not
      def plain_branch(args)
        return nil if args.intersect?(NOT_CREATING)

        args.find { |arg| !arg.start_with?('-') }
      end

      def worktree(args)
        return nil unless args.first == 'add'

        rest = args.drop(1)
        named = flagged(rest, %w[-b -B])
        return named if named
        return nil if rest.include?('--detach') || rest.include?('--orphan')

        path = positional(rest)
        path.size == 1 ? File.basename(path.first) : nil
      end

      # Arguments that are not options or the values of options that take one
      def positional(args)
        result = []
        skip = false
        args.each do |arg|
          if skip
            skip = false
          elsif WORKTREE_VALUE_OPTIONS.include?(arg)
            skip = true
          elsif !arg.start_with?('-')
            result << arg
          end
        end
        result
      end
    end
  end
end
