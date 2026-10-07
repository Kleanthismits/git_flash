# frozen_string_literal: true

module Gitflash
  module Commands
    # How `pick` and its --continue / --skip / --abort report a git cherry-pick run: done, or
    # stopped on conflicts (status `failed`, error code `conflict`) with what is left to do.
    module PickOutcome
      private

      def cherry_pick
        @cherry_pick ||= CherryPick.new
      end

      # `requested` are the commits the user asked for, in order; `snapshot` reverts the start
      def outcome(plan, result, requested, snapshot)
        return finished(plan, requested, snapshot) if result.success? && !cherry_pick.in_progress?
        return conflict(plan, result, requested, snapshot) if cherry_pick.in_progress?

        git_error!('cherry-pick', result)
      end

      def finished(plan, requested, snapshot)
        head = repo.resolve_commit('HEAD')
        text = "Applied #{requested.size} commit(s), now at #{head[0, 7]}"
        ui.report(status: 'done', plan: plan, result: { applied: requested, head: head },
                  undo: snapshot, text: text)
      end

      def conflict(plan, result, requested, snapshot)
        progress = cherry_pick.progress
        text = conflict_text(progress, result)
        details = { applied: requested - progress.remaining - [progress.current],
                    current: progress.current, conflicted: progress.conflicted,
                    remaining: progress.remaining }
        ui.report(status: 'failed', plan: plan, result: details, undo: snapshot, text: text,
                  error: { code: 'conflict', exit_code: 1, message: text })
      end

      def conflict_text(progress, result)
        files = progress.conflicted.map { |file| "* #{file}" }.join("\n")
        "Stopped on conflicts in:\n#{files}\n#{result.output}\n" \
          'Resolve them and stage the files, then run `gitflash pick --continue`; ' \
          'or `gitflash pick --skip` / `gitflash pick --abort`.'
      end

      def current_branch_names
        branch = repo.current_branch
        branch ? [branch] : []
      end
    end
  end
end
