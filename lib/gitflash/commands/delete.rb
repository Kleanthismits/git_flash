# frozen_string_literal: true

module Gitflash
  module Commands
    # Deletes local branches given as arguments or picked from a menu.
    # Uses `git branch -d` (merged branches only) unless --force is given.
    class Delete < Base
      PROTECTED_NAMES = %w[main master].freeze

      def call(*names)
        branches = repo.branches
        candidates = branches.reject { |branch| protected?(branch) }.map(&:name)

        names = pick(candidates) if names.empty?
        return 0 if names.nil?

        validate!(names.uniq, branches)
        delete(names.uniq)
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
        raise UsageError, "Unknown branch: #{unknown.join(', ')}" if unknown.any?

        refused = names.select { |name| protected?(by_name[name]) }
        return if refused.empty?

        raise UsageError, "Refusing to delete protected branches: #{refused.join(', ')} " \
                          '(current, default, main and master are protected)'
      end

      def delete(names)
        plan = { action: 'delete', force: force?, branches: names }
        return report_dry_run(plan) if ui.dry_run?
        return report_cancelled(plan) unless ui.confirm?(summary(names), details: plan)

        results = names.map { |name| delete_one(name) }
        report_results(plan, results)
      end

      def delete_one(name)
        result = repo.delete_branch(name, force: force?)
        return { branch: name, deleted: true } if result.success?

        { branch: name, deleted: false, error: result.output }
      end

      def summary(names)
        mode = force? ? 'even if they have unmerged changes' : 'if they are fully merged'
        "You are about to delete the following branches #{mode}:\n\n#{bullets(names)}"
      end

      def bullets(names)
        names.map { |name| "* #{name}" }.join("\n")
      end

      def report_nothing(text)
        ui.emit({ action: 'delete', force: force?, branches: [], results: [] }, text)
        nil
      end

      def report_dry_run(plan)
        ui.emit(plan.merge(dry_run: true), "Would delete:\n#{bullets(plan[:branches])}")
        0
      end

      def report_cancelled(plan)
        ui.emit(plan.merge(cancelled: true), 'Exited')
        0
      end

      def report_results(plan, results)
        failed = results.reject { |result| result[:deleted] }
        ui.emit(plan.merge(results: results), results_text(results, failed))
        failed.empty? ? 0 : 1
      end

      def results_text(results, failed)
        lines = results.map do |result|
          next "Deleted branch #{result[:branch]}" if result[:deleted]

          "Not deleted #{result[:branch]}: #{result[:error]}"
        end
        lines << 'Use --force to delete branches with unmerged changes.' if failed.any? && !force?
        lines.join("\n")
      end
    end
  end
end
