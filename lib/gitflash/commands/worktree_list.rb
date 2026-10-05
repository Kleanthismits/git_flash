# frozen_string_literal: true

module Gitflash
  module Commands
    # Lists the worktrees of the repository
    class WorktreeList < Base
      def call
        worktrees = Worktrees.new(repo: repo).list
        ui.report(status: 'done', result: { worktrees: worktrees.map(&:to_h) },
                  text: table(worktrees))
      end

      private

      def table(worktrees)
        width = worktrees.map { |worktree| worktree.path.length }.max
        worktrees.map { |worktree| row(worktree, width) }.join("\n")
      end

      def row(worktree, width)
        [worktree.path.ljust(width), worktree.branch || "(detached #{worktree.head.to_s[0, 7]})",
         flags(worktree)].join('  ').rstrip
      end

      def flags(worktree)
        labels = state_labels(worktree) + position_labels(worktree)
        labels.select { |_label, shown| shown }.map(&:first).join(', ')
      end

      def state_labels(worktree)
        [['main', worktree.main?], ['dirty', worktree.dirty?], ['locked', worktree.locked?],
         ['missing', worktree.missing?], ['merged', worktree.merged && !worktree.main?]]
      end

      def position_labels(worktree)
        [["ahead #{worktree.ahead}", worktree.ahead.to_i.positive?],
         ["behind #{worktree.behind}", worktree.behind.to_i.positive?]]
      end
    end
  end
end
