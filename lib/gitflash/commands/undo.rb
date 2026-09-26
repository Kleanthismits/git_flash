# frozen_string_literal: true

module Gitflash
  module Commands
    # Restores a snapshot (the latest one by default). The current state is saved first,
    # so an undo can itself be undone.
    class Undo < Base
      def call(id = nil)
        snapshot = find(id)
        return no_snapshots unless snapshot

        check_worktree!(snapshot)
        restore = Restore.new(snapshot)
        plan = restore.plan.merge(snapshot: snapshot.id)
        return nothing_to_undo(plan) if restore.empty?

        restore!(snapshot, restore, plan)
      end

      private

      def find(id)
        return snapshots.list.first if id.nil?

        snapshots.find(id) || usage_error!('unknown_snapshot', "Unknown snapshot '#{id}'")
      end

      # Branches are shared between worktrees; HEAD and files belong to one worktree
      def check_worktree!(snapshot)
        return unless snapshot.scope?('head') || snapshot.scope?('worktree')
        return if snapshot.worktree_path == repo.toplevel

        usage_error!('wrong_worktree', "Snapshot #{snapshot.id} was taken in " \
                                       "#{snapshot.worktree_path}; run gitflash undo there")
      end

      def restore!(snapshot, restore, plan)
        text = "snapshot #{snapshot.id}:\n#{describe(plan)}"
        return planned(plan, "Would restore #{text}") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?(summary(snapshot, plan), plan: plan)

        apply(snapshot, restore, plan)
      end

      def apply(snapshot, restore, plan)
        before = snapshots.create(reason: "before undo #{snapshot.id}", scope: snapshot.scope,
                                  branches: snapshot.branches.keys)
        failure = restore.apply
        raise_failure(failure, before, plan) if failure

        ui.report(status: 'done', plan: plan, result: { snapshot: snapshot.id }, undo: before,
                  text: "Restored snapshot #{snapshot.id}:\n#{describe(plan)}")
      end

      def raise_failure(failure, before, plan)
        message = "gitflash undo failed:\n#{failure.output}\n" \
                  "The state before this undo is saved as snapshot #{before.id}."
        raise Error.new(message, code: 'git_failed', plan: plan)
      end

      def no_snapshots
        ui.report(status: 'noop', result: { snapshot: nil }, text: 'No snapshots to undo')
      end

      def nothing_to_undo(plan)
        text = "Nothing to undo: the repository already matches snapshot #{plan[:snapshot]}"
        ui.report(status: 'noop', plan: plan, result: { snapshot: plan[:snapshot] }, text: text)
      end

      def summary(snapshot, plan)
        "You are about to restore snapshot #{snapshot.id} " \
          "(#{snapshot.reason}, #{snapshot.created_at}):\n#{describe(plan)}"
      end

      def describe(plan)
        lines = plan[:branches].map { |change| branch_line(change) }
        lines << head_line(plan[:head]) if plan[:head]
        lines << '* restore tracked, staged and untracked files' if plan[:worktree]
        lines << "* restore #{plan[:stashes].size} stash entries" if plan[:stashes].any?
        lines.join("\n")
      end

      def branch_line(change)
        target = change[:to][0, 7]
        return "* recreate #{change[:branch]} at #{target}" unless change[:from]

        "* move #{change[:branch]} back to #{target}"
      end

      def head_line(head)
        "* switch HEAD from #{short(head[:from])} to #{short(head[:to])}"
      end

      def short(ref)
        ref.to_s.match?(/\A\h{40}\z/) ? ref[0, 7] : ref.to_s
      end
    end
  end
end
