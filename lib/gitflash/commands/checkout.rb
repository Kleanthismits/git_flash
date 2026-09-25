# frozen_string_literal: true

module Gitflash
  module Commands
    # Checks out a local branch given as an argument or picked from a menu
    class Checkout < Base
      def call(name = nil)
        branches = repo.branches
        current = branches.find(&:current?)&.name

        if name.nil?
          require_interactive!('Pass the branch to check out: gitflash checkout BRANCH')
          return noop(current, 'You only have one branch!') if branches.size < 2

          name = pick(branches, current)
        end

        checkout(name, branches.map(&:name), current)
      end

      private

      def pick(branches, current)
        select_options = current.nil? ? {} : { default: current }
        ui.select('Select a branch to checkout', branches.map(&:name), **select_options)
      end

      def checkout(name, names, current)
        usage_error!('unknown_branch', "Unknown branch '#{name}'") unless names.include?(name)
        return noop(name, "Already on '#{name}'") if name == current

        plan = { branch: name }
        return planned(plan, "Would check out '#{name}'") if ui.dry_run?

        result = repo.checkout(name)
        git_error!('checkout', result) unless result.success?

        ui.report(status: 'done', plan: plan, result: { branch: name, previous_branch: current },
                  text: "Switched to branch '#{name}'")
      end

      def noop(branch, text)
        ui.report(status: 'noop', result: { branch: branch, previous_branch: branch }, text: text)
      end
    end
  end
end
