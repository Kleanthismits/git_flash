# frozen_string_literal: true

module Gitflash
  module Commands
    # Reports the outcome of removing worktrees: one row per worktree with its own snapshot and
    # undo command, failures with their reason. Used by `wt remove` and `wt clean`.
    module RemovalReport
      # What happened to one worktree; `snapshot` is nil when it was not removed
      Removal = Data.define(:worktree, :result, :snapshot)

      private

      # Ignored files are never saved by snapshots, so `undo` cannot bring them back
      def ignored_warning(plan)
        rows = plan[:worktrees].select { |row| row[:ignored_count].positive? }
        return '' if rows.empty?

        lines = rows.map { |row| ignored_line(row) }
        "\n\nIgnored files are not saved by snapshots and will be lost for good:\n" \
          "#{lines.join("\n")}"
      end

      def ignored_line(row)
        "* #{TerminalText.line(row[:path])}: #{row[:ignored_count]} " \
          "(#{TerminalText.line(row[:ignored].join(', '))})"
      end

      def report_results(plan, outcomes)
        removed, failed = outcomes.partition { |outcome| outcome.result.success? }
        result = { removed: removed.map { |outcome| removed_row(outcome) },
                   failed: failed.map { |outcome| failed_row(outcome) } }
        ui.report(status: failed.empty? ? 'done' : 'failed', plan: plan, result: result,
                  error: failure(failed, outcomes), text: results_text(result),
                  undo: single_undo(removed))
      end

      # `undo` in the envelope only when one worktree was removed; each row has its own
      def single_undo(removed)
        removed.first.snapshot if removed.size == 1
      end

      def failed_row(outcome)
        { path: outcome.worktree.path, error: outcome.result.output }
      end

      def removed_row(outcome)
        worktree = outcome.worktree
        { path: worktree.path, branch: worktree.branch, head: worktree.head,
          snapshot: outcome.snapshot.id, undo: "gitflash undo #{outcome.snapshot.id}" }
      end

      def failure(failed, outcomes)
        return nil if failed.empty?

        { code: 'git_failed', exit_code: 1,
          message: "#{failed.size} of #{outcomes.size} worktrees were not removed" }
      end

      def results_text(result)
        lines = result[:removed].map do |row|
          "Removed #{TerminalText.line(row[:path])} (undo: #{row[:undo]})"
        end
        lines += result[:failed].map do |row|
          "Not removed #{TerminalText.line(row[:path])}: #{row[:error]}"
        end
        lines.join("\n")
      end
    end
  end
end
