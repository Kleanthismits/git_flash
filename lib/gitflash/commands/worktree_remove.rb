# frozen_string_literal: true

module Gitflash
  module Commands
    # Removes worktrees given as paths or branch names, or picked from a menu.
    # The main checkout, the worktree gitflash runs in, locked and dirty worktrees are refused
    # unless --force is given (the main checkout and the current one never can be removed).
    # Each removal saves a snapshot of the worktree first; `gitflash undo ID` brings the
    # directory, its branch and its uncommitted files back.
    class WorktreeRemove < Base
      def call(*targets)
        worktrees = Worktrees.new(repo: repo).list
        targets = pick(worktrees) if targets.empty?
        return 0 if targets.nil?

        chosen = resolve(targets, worktrees)
        remove(chosen)
      end

      private

      def pick(worktrees)
        require_interactive!('Pass the worktrees to remove: gitflash wt remove PATH_OR_BRANCH...')
        choices = worktrees.reject { |worktree| worktree.main? || current?(worktree) }
                           .to_h { |wt| ["#{wt.branch || '(detached)'}  #{wt.path}", wt.path] }
        return report_nothing('No worktrees available to remove') if choices.empty?

        picked = ui.multi_select('Select worktrees to remove', choices)
        picked.empty? ? report_nothing('No worktrees selected') : picked
      end

      def force?
        options[:force] ? true : false
      end

      def current?(worktree)
        worktree.path == repo.toplevel
      end

      def resolve(targets, worktrees)
        chosen = targets.uniq.map { |target| find(target, worktrees) }.uniq(&:path)
        refused = chosen.filter_map do |worktree|
          worktree.removal_blocker(force: force?, current: current?(worktree))
        end
        usage_error!('protected_worktree', refused.join('; ')) if refused.any?
        chosen
      end

      def find(target, worktrees)
        path = File.expand_path(target)
        worktrees.find { |worktree| worktree.path == path || worktree.branch == target } ||
          usage_error!('unknown_worktree', "Unknown worktree: #{target}")
      end

      def remove(chosen)
        plan = { worktrees: chosen.map { |worktree| plan_row(worktree) }, force: force? }
        return planned(plan, "Would remove:\n#{bullets(chosen)}") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?(summary(chosen), plan: plan)

        outcomes = chosen.map { |worktree| remove_one(worktree) }
        report_results(plan, outcomes)
      end

      def plan_row(worktree)
        { path: worktree.path, branch: worktree.branch, dirty: worktree.dirty?,
          locked: worktree.locked? }
      end

      Removal = Data.define(:worktree, :result, :snapshot)

      def remove_one(worktree)
        snapshot = snapshot_for(worktree)
        result = Worktrees.new(repo: repo).remove(worktree.path, force: force?)
        Removal.new(worktree: worktree, result: result, snapshot: (snapshot if result.success?))
      end

      # A missing directory has no HEAD or files to save; only the branch tip is
      def snapshot_for(worktree)
        reason = "gitflash wt remove #{worktree.path}"
        branches = [worktree.branch].compact
        return take_snapshot(reason, scope: %w[branches], branches: branches) if worktree.missing?

        take_snapshot(reason, scope: %w[branches head worktree], branches: branches,
                              dir: worktree.path)
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
        lines = result[:removed].map { |row| "Removed #{row[:path]} (undo: #{row[:undo]})" }
        lines += result[:failed].map { |row| "Not removed #{row[:path]}: #{row[:error]}" }
        lines.join("\n")
      end

      def summary(chosen)
        "You are about to remove the following worktrees:\n\n#{bullets(chosen)}"
      end

      def bullets(chosen)
        chosen.map { |worktree| "* #{worktree.path} (#{worktree.branch || 'detached'})" }.join("\n")
      end

      def report_nothing(text)
        ui.report(status: 'noop', result: { removed: [], failed: [] }, text: text)
        nil
      end
    end
  end
end
