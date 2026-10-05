# frozen_string_literal: true

module Gitflash
  module Commands
    # Shared lookup for the `worktree` commands that act on one worktree
    class WorktreeCommand < Base
      private

      def worktrees
        @worktrees ||= Worktrees.new(repo: repo)
      end

      # The worktree named by a path or a branch; raises `unknown_worktree` when none matches
      def find!(target, list = worktrees.list)
        path = File.expand_path(target)
        list.find { |worktree| worktree.path == path || worktree.branch == target } ||
          usage_error!('unknown_worktree', "Unknown worktree: #{target}")
      end

      def refuse_main!(worktree, action)
        return unless worktree.main?

        usage_error!('protected_worktree',
                     "#{worktree.path} is the main checkout; cannot #{action}")
      end
    end
  end
end
