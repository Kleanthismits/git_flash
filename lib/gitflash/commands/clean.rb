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

      # Sets @reasons (chosen branch => why) and @skipped (matches kept for being unmerged, and
      # unused branches)
      def select(branches)
        chosen, kept = candidates(branches)
        @reasons = chosen.to_h { |candidate| [candidate.item.name, candidate.reasons] }
        @skipped = kept.map { |candidate| skipped_row(candidate) } + held_back(branches)
      end

      # [chosen, kept for being unmerged]
      def candidates(branches)
        Cleanup.branches(branches, rules: rules, protection: protection)
               .partition { |candidate| force? || candidate.item.merged }
      end

      def held_back(branches)
        Cleanup.held_back(branches, rules: rules, protection: protection)
      end

      def build_plan(names)
        plan = super.merge(reasons: @reasons.slice(*names), skipped: @skipped)
        warning ? plan.merge(warning: warning) : plan
      end

      def summary(names)
        warning ? "#{super}\n\nNote: #{warning}" : super
      end

      # Without origin/HEAD, "merged" means merged into a local main or master, which may not be
      # the branch the team ships from
      def warning
        return @warning if defined?(@warning)

        @warning = if default_branch_guessed?
                     'origin/HEAD is not set, so gitflash guessed the default branch ' \
                       "(#{repo.default_branch || 'none'}). Run `git remote set-head origin " \
                       '--auto` so merged branches are judged against the right one.'
                   end
      end

      # An origin remote but no origin/HEAD: the default branch came from a local main or master
      def default_branch_guessed?
        _out, _err, set = Git::BashCommand.capture('git', 'symbolic-ref', '--quiet',
                                                   "#{Repo::REMOTE_HEAD}HEAD")
        return false if set

        remotes, _err, = Git::BashCommand.capture('git', 'remote')
        remotes.split.include?('origin')
      end

      def skipped_row(candidate)
        { branch: candidate.item.name, reason: 'has unmerged changes (use --force)' }
      end

      def nothing_to_clean
        plan = { branches: [], force: force?, reasons: {}, skipped: @skipped }
        plan[:warning] = warning if warning
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
