# frozen_string_literal: true

module Gitflash
  module Commands
    # Removes the worktrees whose branch is no longer needed (same criteria as `clean`).
    # Main, current, locked and dirty worktrees are skipped with the reason unless --force
    # allows locked and dirty ones; the main checkout and the current worktree never go.
    # Removal, snapshots and undo work as in `wt remove`. Branches are kept: run `gitflash clean`
    # afterwards to delete them. Worktrees with a missing directory belong to `wt prune`.
    class WorktreeClean < WorktreeRemove
      include CleanCriteria

      def call
        chosen, @skipped = select
        @reasons = chosen.to_h { |candidate| [candidate.item.path, candidate.reasons] }
        return nothing_to_clean if chosen.empty?

        remove(chosen.map(&:item))
      end

      private

      def select
        Cleanup.worktrees(worktrees.list, branches: repo.branches(merged_status: true),
                                          rules: rules, protection: Protection.new(config: config),
                                          blocker: ->(worktree) { blocker(worktree) })
      end

      def blocker(worktree)
        worktree.removal_blocker(force: force?, current: current?(worktree))
      end

      def build_plan(chosen)
        super.merge(skipped: @skipped)
      end

      def plan_row(worktree)
        super.merge(reasons: @reasons[worktree.path])
      end

      def nothing_to_clean
        plan = { worktrees: [], force: force?, skipped: @skipped }
        text = (['Nothing to clean'] + @skipped.map { |row| "Kept #{row[:path]}: #{row[:reason]}" })
        ui.report(status: 'noop', plan: plan, result: { removed: [], failed: [] },
                  text: text.join("\n"))
      end
    end
  end
end
