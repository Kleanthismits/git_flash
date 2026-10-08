# frozen_string_literal: true

module Gitflash
  module Commands
    # Forgets worktrees whose directory is gone (locked ones stay). Branches are not touched.
    # Takes no snapshot: only git's own bookkeeping for the missing directory is removed.
    class WorktreePrune < WorktreeCommand
      def call
        stale = worktrees.list.select { |worktree| worktree.missing? && !worktree.locked? }
        return noop if stale.empty?

        prune_or_ask({ worktrees: stale.map(&:path) })
      end

      private

      def prune_or_ask(plan)
        return planned(plan, "Would prune:\n#{bullets(plan)}") if ui.dry_run?

        question = "You are about to prune:\n\n#{bullets(plan)}"
        ui.confirm?(question, plan: plan) ? prune(plan) : cancelled(plan)
      end

      def prune(plan)
        result = worktrees.prune
        git_error!('worktree prune', result) unless result.success?

        ui.report(status: 'done', plan: plan, result: { pruned: plan[:worktrees] },
                  text: "Pruned:\n#{bullets(plan)}")
      end

      def noop
        ui.report(status: 'noop', result: { pruned: [] }, text: 'No missing worktrees to prune')
      end

      def bullets(plan)
        plan[:worktrees].map { |path| "* #{TerminalText.line(path)}" }.join("\n")
      end
    end
  end
end
