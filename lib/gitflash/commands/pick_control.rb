# frozen_string_literal: true

module Gitflash
  module Commands
    # `gitflash pick --continue`, `--skip` or `--abort`: wraps git's own cherry-pick controls for
    # a pick that stopped on conflicts. --skip and --abort discard work in progress, so they ask
    # for confirmation and save a snapshot first; --continue adds to the work and does not.
    class PickControl < Base
      include PickOutcome

      ACTIONS = %w[continue skip abort].freeze

      def call(*)
        action = chosen_action
        usage_error!('invalid_usage', 'No cherry-pick in progress') unless cherry_pick.in_progress?

        plan = build_plan(action)
        return perform(action, plan, nil) if action == 'continue'
        return planned(plan, "Would #{action} the cherry-pick in progress") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?(summary(action), plan: plan)

        perform(action, plan, take_snapshot("gitflash pick --#{action}", scope: %w[head worktree]))
      end

      private

      def chosen_action
        given = ACTIONS.select { |action| options[action.to_sym] }
        return given.first if given.one?

        usage_error!('invalid_options', 'Use exactly one of --continue, --skip or --abort')
      end

      def build_plan(action)
        progress = cherry_pick.progress
        { action: action, current: progress.current, conflicted: progress.conflicted,
          remaining: progress.remaining }
      end

      def summary(action)
        "You are about to #{action} the cherry-pick in progress; " \
          'the conflict resolution made so far is discarded.'
      end

      def perform(action, plan, snapshot)
        result = cherry_pick.public_send(action == 'continue' ? :continue : action.to_sym)
        return outcome_after(action, plan, result, snapshot) if action != 'abort'

        git_error!('cherry-pick --abort', result) unless result.success?
        finish(action, plan, snapshot)
      end

      def outcome_after(action, plan, result, snapshot)
        return conflict(plan, result, [], snapshot) if cherry_pick.in_progress?

        git_error!("cherry-pick --#{action}", result) unless result.success?
        finish(action, plan, snapshot)
      end

      def finish(action, plan, snapshot)
        head = repo.resolve_commit('HEAD')
        ui.report(status: 'done', plan: plan, result: { action: action, head: head },
                  undo: snapshot, text: "Cherry-pick #{action} done, now at #{head[0, 7]}")
      end
    end
  end
end
