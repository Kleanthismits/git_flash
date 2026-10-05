# frozen_string_literal: true

module Gitflash
  module Commands
    # Deletes the branches that are no longer needed: merged ones and ones whose upstream is
    # gone by default, plus stale or agent-created ones when asked. Protected branches and
    # branches checked out in a worktree are never selected. Unmerged branches are kept unless
    # --force is given. Plan, confirmation, snapshot and result work as in `delete`; each chosen
    # branch carries the reasons it was chosen.
    class Clean < Delete
      include CleanCriteria

      def call
        branches = repo.branches(merged_status: true)
        select(branches)
        return nothing_to_clean if @reasons.empty?

        delete(@reasons.keys, branches.to_h { |branch| [branch.name, branch.sha] })
      end

      private

      # Sets @reasons (chosen branch => why) and @skipped (matches kept for being unmerged)
      def select(branches)
        candidates = Cleanup.branches(branches, rules: rules, protection: protection)
        chosen, kept = candidates.partition { |candidate| force? || candidate.item.merged }
        @reasons = chosen.to_h { |candidate| [candidate.item.name, candidate.reasons] }
        @skipped = kept.map { |candidate| skipped_row(candidate) }
      end

      def build_plan(names)
        super.merge(reasons: @reasons.slice(*names), skipped: @skipped)
      end

      def skipped_row(candidate)
        { branch: candidate.item.name, reason: 'has unmerged changes (use --force)' }
      end

      def nothing_to_clean
        plan = { branches: [], force: force?, reasons: {}, skipped: @skipped }
        ui.report(status: 'noop', plan: plan, result: { deleted: [], failed: [] },
                  text: @skipped.empty? ? 'Nothing to clean' : skipped_text)
      end

      def skipped_text
        lines = @skipped.map { |row| "Kept #{row[:branch]}: #{row[:reason]}" }
        (['Nothing to clean.'] + lines).join("\n")
      end
    end
  end
end
