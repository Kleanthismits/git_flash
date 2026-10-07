# frozen_string_literal: true

module Gitflash
  module Commands
    # Moves a worktree to another directory. Refuses the main checkout, the current worktree
    # (its directory would disappear under the caller) and locked worktrees unless --force.
    # Needs no confirmation: moving it back reverses it.
    class WorktreeMove < WorktreeCommand
      def call(target = nil, destination = nil)
        unless target && destination
          usage_error!('invalid_usage',
                       'Pass the worktree and its new path')
        end
        worktree = find!(target)
        check!(worktree)
        plan = { from: worktree.path, to: File.expand_path(destination), force: force? }
        return planned(plan, "Would move #{plan[:from]} to #{plan[:to]}") if ui.dry_run?

        move(plan)
      end

      private

      def force?
        options[:force] ? true : false
      end

      def check!(worktree)
        refuse_main!(worktree, 'move')
        if worktree.path == repo.toplevel
          usage_error!('protected_worktree', "#{worktree.path} is the current worktree")
        end
        return unless worktree.locked? && !force?

        usage_error!('protected_worktree', "#{worktree.path} is locked (use --force)")
      end

      def move(plan)
        result = worktrees.move(plan[:from], plan[:to], force: plan[:force])
        git_error!('worktree move', result) unless result.success?

        ui.report(status: 'done', plan: plan, result: plan.slice(:from, :to),
                  text: "Moved #{plan[:from]} to #{plan[:to]}")
      end
    end
  end
end
