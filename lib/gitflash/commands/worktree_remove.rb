# frozen_string_literal: true

module Gitflash
  module Commands
    # Removes worktrees given as paths or branch names, or picked from a menu.
    # The main checkout, the worktree gitflash runs in, locked and dirty worktrees are refused
    # unless --force is given (the main checkout and the current one never can be removed).
    # Each removal saves a snapshot of the worktree first; `gitflash undo ID` brings the
    # directory, its branch and its uncommitted files back.
    class WorktreeRemove < WorktreeCommand
      include RemovalReport

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
        chosen = targets.uniq.map { |target| find!(target, worktrees) }.uniq(&:path)
        refused = chosen.filter_map do |worktree|
          worktree.removal_blocker(force: force?, current: current?(worktree))
        end
        usage_error!('protected_worktree', refused.join('; ')) if refused.any?
        chosen
      end

      def remove(chosen)
        plan = build_plan(chosen)
        return planned(plan, "Would remove:\n#{bullets(chosen)}") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?(summary(chosen), plan: plan)

        outcomes = chosen.map { |worktree| remove_one(worktree) }
        report_results(plan, outcomes)
      end

      # The plan reported and returned in JSON; `wt clean` adds why each worktree was chosen
      def build_plan(chosen)
        { worktrees: chosen.map { |worktree| plan_row(worktree) }, force: force? }
      end

      def plan_row(worktree)
        { path: worktree.path, branch: worktree.branch, dirty: worktree.dirty?,
          locked: worktree.locked? }
      end

      def remove_one(worktree)
        snapshot = snapshot_for(worktree)
        unsaved = snapshot.skipped_files
        return refuse_unsaved(worktree, unsaved) if unsaved.any?

        result = Worktrees.new(repo: repo).remove(worktree.path, force: force?)
        Removal.new(worktree: worktree, result: result, snapshot: (snapshot if result.success?))
      end

      # Files a snapshot cannot hold (untracked and over 50 MB) would be lost for good
      def refuse_unsaved(worktree, files)
        shown = files.first(3).join(', ')
        shown += ", and #{files.size - 3} more" if files.size > 3
        message = "#{files.size} untracked file(s) over 50 MB cannot be saved by a snapshot " \
                  "(#{shown}); move or delete them first"
        Removal.new(worktree: worktree, result: Result.new(success: false, output: message),
                    snapshot: nil)
      end

      # A missing directory has no HEAD or files to save; only the branch tip is
      def snapshot_for(worktree)
        reason = "gitflash wt remove #{worktree.path}"
        branches = [worktree.branch].compact
        return take_snapshot(reason, scope: %w[branches], branches: branches) if worktree.missing?

        take_snapshot(reason, scope: %w[branches head worktree], branches: branches,
                              dir: worktree.path)
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
