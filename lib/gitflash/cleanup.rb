# frozen_string_literal: true

module Gitflash
  # Decides what `clean` and `wt clean` would remove. Pure: it reads records and settings, runs
  # no git command, so every rule can be tested without a repository.
  module Cleanup
    CRITERIA = %i[merged gone stale agent].freeze
    DEFAULT_CRITERIA = %i[merged gone].freeze

    # A record chosen for removal and why. `item` is a Branch or a Worktree.
    Candidate = Data.define(:item, :reasons)

    # Which criteria are active. `stale_days` applies to :stale.
    Rules = Data.define(:criteria, :stale_days, :now) do
      def reasons(branch)
        criteria.filter_map { |criterion| label(criterion) if match?(criterion, branch) }
      end

      private

      def match?(criterion, branch)
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

    # Worktrees whose unprotected branch matches, as [chosen, skipped]. `blocker` is called with
    # a worktree and returns why it may not be removed, or nil. A blocked match is skipped with
    # that reason instead of being chosen.
    def worktrees(worktrees, branches:, rules:, protection:, blocker:)
      matched = matching(worktrees, branches, rules, protection)
      chosen, skipped = matched.partition { |candidate| blocker.call(candidate.item).nil? }
      [chosen, skipped.map { |candidate| skip(candidate.item, blocker.call(candidate.item)) }]
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
