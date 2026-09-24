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
          return report(nil, changed: false, text: 'You only have one branch!') if branches.size < 2

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
        raise UsageError, "Unknown branch '#{name}'" unless names.include?(name)
        return report(name, changed: false, text: "Already on '#{name}'") if name == current
        if ui.dry_run?
          return report(name, changed: false, dry_run: true, text: "Would check out '#{name}'")
        end

        result = repo.checkout(name)
        raise Error, "git checkout failed:\n#{result.output}" unless result.success?

        report(name, changed: true, text: "Switched to branch '#{name}'")
      end

      def report(name, changed:, text:, dry_run: false)
        ui.emit({ action: 'checkout', branch: name, changed: changed, dry_run: dry_run }, text)
        0
      end
    end
  end
end
