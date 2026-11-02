# frozen_string_literal: true

module Gitflash
  # Decides what `clean` and `wt clean` would remove. Pure: it reads records and settings, runs
  # no git command, so every rule can be tested without a repository.
  module Cleanup
    CRITERIA = %i[merged gone stale agent].freeze
    DEFAULT_CRITERIA = %i[merged gone].freeze
    # Criteria that do not choose an unused branch
    NEW_BRANCH_SAFE = %i[merged agent].freeze

    # A record chosen for removal and why. `item` is a Branch or a Worktree.
    Candidate = Data.define(:item, :reasons)

    # Which criteria are active. `stale_days` applies to :stale.
    #
    # A branch nobody has used since it was created (Branch#unused) is new, not finished, even
    # though it is reachable from the default branch and may be marked as agent work: someone
    # may be about to work on it. :merged and :agent leave it alone; :stale removes it once it
    # has been unused for `stale_days`, and :gone when its remote branch was deleted.
    Rules = Data.define(:criteria, :stale_days, :now) do
      def reasons(branch)
        criteria.filter_map { |criterion| label(criterion) if match?(criterion, branch) }
      end

      # Why a branch that a criterion would have chosen if it were not unused is kept, or nil
      def held_back(branch)
        return nil unless branch.unused && reasons(branch).empty?
        return nil unless criteria.any? { |criterion| fits?(criterion, branch) }

        "no commits since it was created; --stale removes it after #{stale_days} days unused"
      end

      private

      def match?(criterion, branch)
        fits?(criterion, branch) && !(branch.unused && NEW_BRANCH_SAFE.include?(criterion))
      end

      def fits?(criterion, branch)
        case criterion
        when :merged then branch.merged && !branch.default?
        when :gone then branch.upstream_gone?
        when :stale then branch.stale?(stale_days, now: now)
        when :agent then branch.owner == 'agent'
        end
      end

      def label(criterion)
        { merged: 'merged', gone: 'upstream gone', agent: 'agent-created',
          stale: "no commits for #{stale_days} days" }.fetch(criterion)
      end
    end

    module_function

    # Branches that match at least one criterion and are not protected, each with its reasons
    def branches(branches, rules:, protection:)
      branches.reject { |branch| protection.protected?(branch) }.filter_map do |branch|
        reasons = rules.reasons(branch)
        Candidate.new(item: branch, reasons: reasons) if reasons.any?
      end
    end

    # Unprotected unused branches that a criterion would have chosen otherwise, as
    # { branch:, reason: } rows
    def held_back(branches, rules:, protection:)
      branches.reject { |branch| protection.protected?(branch) }.filter_map do |branch|
        reason = rules.held_back(branch)
        { branch: branch.name, reason: reason } if reason
      end
    end

    # Worktrees whose unprotected branch matches, as [chosen, skipped]. `blocker` is called with
    # a worktree and returns why it may not be removed, or nil. A blocked match is skipped with
    # that reason instead of being chosen.
    # A worktree whose branch is unused is skipped with that reason too.
    def worktrees(worktrees, branches:, rules:, protection:, blocker:)
      matched = matching(worktrees, branches, rules, protection)
      chosen, skipped = matched.partition { |candidate| blocker.call(candidate.item).nil? }
      [chosen, skipped.map { |candidate| skip(candidate.item, blocker.call(candidate.item)) } +
        held_back_worktrees(worktrees, branches, rules, protection)]
    end

    def held_back_worktrees(worktrees, branches, rules, protection)
      by_name = branches.to_h { |branch| [branch.name, branch] }
      worktrees.filter_map do |worktree|
        branch = by_name[worktree.branch]
        next if branch.nil? || protection.protected?(branch)

        reason = rules.held_back(branch)
        skip(worktree, "#{worktree.branch} has #{reason}") if reason
      end
    end

    def matching(worktrees, branches, rules, protection)
      by_name = branches.to_h { |branch| [branch.name, branch] }
      worktrees.filter_map do |worktree|
        branch = by_name[worktree.branch]
        next if branch.nil? || protection.protected?(branch)

        reasons = rules.reasons(branch)
        Candidate.new(item: worktree, reasons: reasons) if reasons.any?
      end
    end

    def skip(worktree, reason)
      { path: worktree.path, branch: worktree.branch, reason: reason }
    end
  end
end
