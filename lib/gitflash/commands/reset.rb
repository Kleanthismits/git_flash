# frozen_string_literal: true

module Gitflash
  module Commands
    # Resets the current branch to a commit given as an argument or picked from a menu.
    # Default mode is mixed; --soft and --hard are supported. Only --hard asks for confirmation.
    class Reset < Base
      HARD_RESET_WARNING = 'You are about to reset your branch and lose all your current changes'

      def call(ref = nil)
        mode = reset_mode

        if ref.nil?
          require_interactive!('Pass the commit to reset to: gitflash reset COMMIT')
          commits = repo.commits
          return report_single_commit(mode) if commits.size < 2

          ref = ui.select('Select a commit to reset to', commits.to_h { |c| [c.label, c.sha] })
        end

        reset(ref, mode)
      end

      private

      def reset_mode
        if options[:soft] && options[:hard]
          raise UsageError, 'Use either --soft or --hard, not both'
        end

        return 'hard' if options[:hard]

        options[:soft] ? 'soft' : 'mixed'
      end

      def reset(ref, mode)
        commit = repo.resolve_commit(ref)
        raise UsageError, "Unknown commit '#{ref}'" if commit.nil?

        plan = { action: 'reset', commit: commit, mode: mode }
        text = "reset to #{commit[0, 7]} (#{mode})"
        return report(plan.merge(dry_run: true), "Would #{text}") if ui.dry_run?
        return report(plan.merge(cancelled: true), 'Exited') unless confirmed?(plan)

        execute(plan)
        report(plan, text.capitalize)
      end

      def execute(plan)
        result = repo.reset(plan[:commit], mode: plan[:mode])
        raise Error, "git reset failed:\n#{result.output}" unless result.success?
      end

      def confirmed?(plan)
        plan[:mode] != 'hard' || ui.confirm?(HARD_RESET_WARNING, details: plan)
      end

      def report_single_commit(mode)
        report({ action: 'reset', commit: nil, mode: mode }, 'You only have one commit!')
      end

      def report(payload, text)
        ui.emit(payload, text)
        0
      end
    end
  end
end
