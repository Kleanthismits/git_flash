# frozen_string_literal: true

module Gitflash
  module Commands
    # Deletes local branches given as arguments or picked from a menu.
    # Uses `git branch -d` (merged branches only) unless --force is given.
    # The result lists each deleted branch with its last commit, so it can be recreated.
    class Delete < Base
      PROTECTED_NAMES = %w[main master].freeze

      def call(*names)
        branches = repo.branches
        candidates = branches.reject { |branch| protected?(branch) }.map(&:name)

        names = pick(candidates) if names.empty?
        return 0 if names.nil?

        validate!(names.uniq, branches)
        delete(names.uniq, branches.to_h { |branch| [branch.name, branch.sha] })
      end

      private

      # Branches picked from the menu, or nil after telling the user there is nothing to delete
      def pick(candidates)
        require_interactive!('Pass the branches to delete: gitflash delete BRANCH...')
        return report_nothing('No branches available to delete') if candidates.empty?

        names = ui.multi_select('Select branches to delete', candidates)
        names.empty? ? report_nothing('No branches selected') : names
      end

      def force?
        options[:force] ? true : false
      end

      def protected?(branch)
        branch.current? || branch.default? || PROTECTED_NAMES.include?(branch.name)
      end

      def validate!(names, branches)
        by_name = branches.to_h { |branch| [branch.name, branch] }
        unknown = names.reject { |name| by_name.key?(name) }
        usage_error!('unknown_branch', "Unknown branch: #{unknown.join(', ')}") if unknown.any?

        refused = names.select { |name| protected?(by_name[name]) }
        return if refused.empty?

        usage_error!('protected_branch',
                     "Refusing to delete protected branches: #{refused.join(', ')} " \
                     '(current, default, main and master are protected)')
      end

      def delete(names, shas)
        plan = { branches: names, force: force? }
        return planned(plan, "Would delete:\n#{bullets(names)}") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?(summary(names), plan: plan)

        outcomes = names.map { |name| [name, repo.delete_branch(name, force: force?)] }
        report_results(plan, outcomes, shas)
      end

      def summary(names)
        mode = force? ? 'even if they have unmerged changes' : 'if they are fully merged'
        "You are about to delete the following branches #{mode}:\n\n#{bullets(names)}"
      end

      def bullets(names)
        names.map { |name| "* #{name}" }.join("\n")
      end

      def report_nothing(text)
        ui.report(status: 'noop', result: { deleted: [], failed: [] }, text: text)
        nil
      end

      def report_results(plan, outcomes, shas)
        deleted, failed = outcomes.partition { |_name, result| result.success? }
        result = {
          deleted: deleted.map { |name, _result| { branch: name, sha: shas[name] } },
          failed: failed.map { |name, result| { branch: name, error: result.output } }
        }
        ui.report(status: failed.empty? ? 'done' : 'failed', plan: plan, result: result,
                  error: failure(failed, outcomes), text: results_text(result))
      end

      def failure(failed, outcomes)
        return nil if failed.empty?

        message = "#{failed.size} of #{outcomes.size} branches were not deleted"
        { code: 'git_failed', message: message, exit_code: 1 }
      end

      def force_hint?(result)
        result[:failed].any? && !force?
      end

      def results_text(result)
        lines = result[:deleted].map { |row| "Deleted branch #{row[:branch]} (was #{row[:sha]})" }
        lines += result[:failed].map { |row| "Not deleted #{row[:branch]}: #{row[:error]}" }
        lines << 'Use --force to delete branches with unmerged changes.' if force_hint?(result)
        lines.join("\n")
      end
    end
  end
end
