# frozen_string_literal: true

module Gitflash
  module Commands
    # Locks or unlocks a worktree, so `prune`, `remove` and `clean` leave it alone.
    # Needs no confirmation: the change is reversed by the opposite command.
    class WorktreeLock < WorktreeCommand
      def call(target = nil)
        unless target
          usage_error!('invalid_usage',
                       "Pass the worktree: gitflash wt #{verb} WORKTREE")
        end
        worktree = find!(target)
        refuse_main!(worktree, verb)
        return noop(worktree) if worktree.locked? == lock?
        if ui.dry_run?
          return planned(plan(worktree),
                         "Would #{verb} #{TerminalText.line(worktree.path)}")
        end

        change(worktree)
      end

      private

      def lock? = true

      def verb = lock? ? 'lock' : 'unlock'

      def plan(worktree)
        { path: worktree.path, reason: (options[:reason] if lock?) }.compact
      end

      def change(worktree)
        result = git_change(worktree)
        git_error!("worktree #{verb}", result) unless result.success?

        report('done', worktree, "#{verb.capitalize}ed #{TerminalText.line(worktree.path)}")
      end

      def git_change(worktree)
        return worktrees.unlock(worktree.path) unless lock?

        worktrees.lock(worktree.path, reason: options[:reason])
      end

      def noop(worktree)
        report('noop', worktree,
               "#{TerminalText.line(worktree.path)} is #{lock? ? 'already locked' : 'not locked'}")
      end

      def report(status, worktree, text)
        ui.report(status: status, plan: plan(worktree), text: text,
                  result: plan(worktree).merge(locked: lock?))
      end
    end
  end
end
