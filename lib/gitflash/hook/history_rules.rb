# frozen_string_literal: true

module Gitflash
  module Hook
    # Rules for the less common git commands that lose work: plumbing that overwrites files,
    # commands that delete the reflog or unreachable objects `gitflash undo` and git rely on,
    # and branch deletion through `git push .`. Same contract as Rules.
    module HistoryRules
      FULL = %w[branches head worktree].freeze
      WORKTREE = { scope: %w[worktree] }.freeze
      PRUNE_NOW = /\A--prune=(?:now|all)\z/

      module_function

      # `git rm -f` drops uncommitted changes in the files it removes
      def rm(args, _dir)
        forced = args.include?('--force') || Rules.short_flags(args).include?('f')
        forced && !args.include?('--cached') ? WORKTREE : nil
      end

      # `git checkout-index -f` overwrites files in the working tree
      def checkout_index(args, _dir)
        args.include?('--force') || Rules.short_flags(args).include?('f') ? WORKTREE : nil
      end

      # `git read-tree -u --reset` overwrites the working tree with the tree it reads
      def read_tree(args, _dir)
        args.include?('-u') && args.include?('--reset') ? WORKTREE : nil
      end

      # Expiring or deleting reflog entries drops the record of where branches were; the
      # snapshot keeps their current tips reachable
      def reflog(args, _dir)
        %w[expire delete].include?(args.first) ? { scope: FULL } : nil
      end

      # Pruning unreachable objects now removes commits only the reflog still pointed at
      def gc(args, _dir)
        args.any? { |arg| arg.match?(PRUNE_NOW) } ? { scope: FULL } : nil
      end

      def prune(_args, _dir)
        { scope: FULL }
      end

      # `git push . :branch`, `git push . --delete branch`: deletes a branch of this repository
      def push(args, _dir)
        positional = args.reject { |arg| arg.start_with?('-') }
        return nil unless positional.first == '.'

        names = deleted_refs(args, positional.drop(1))
        return nil if names.nil?

        # Names the shell or xargs fills in are unknown: save every branch
        names = [] if names.any? { |name| Paths.unresolved?(name) || name.include?('{}') }
        { scope: %w[branches], branches: names }
      end

      # Branch names a local push deletes: every ref with --delete, else the `:ref` ones.
      # [] when --delete names no refs (they come from stdin, as with xargs): every branch is
      # saved; nil when the push deletes nothing
      def deleted_refs(args, refs)
        delete = args.include?('--delete') || Rules.short_flags(args).include?('d')
        refs = refs.select { |ref| ref.start_with?(':') } unless delete
        return nil if refs.empty? && !delete

        refs.map { |ref| ref.delete_prefix(':').delete_prefix(Repo::HEADS) }
      end

      RULES = {
        'rm' => method(:rm),
        'checkout-index' => method(:checkout_index),
        'read-tree' => method(:read_tree),
        'reflog' => method(:reflog),
        'gc' => method(:gc),
        'prune' => method(:prune),
        'push' => method(:push)
      }.freeze
    end
  end
end
