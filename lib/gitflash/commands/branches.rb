# frozen_string_literal: true

module Gitflash
  module Commands
    # Lists local branches, optionally filtered to merged, gone or stale ones
    class Branches < Base
      def call
        branches = filter(repo.branches(merged_status: true))
        payload = { default_branch: repo.default_branch, branches: branches.map(&:to_h) }
        ui.emit(payload, table(branches))
        0
      end

      private

      # A branch is listed when it matches any of the given filters
      def filter(branches)
        filters = active_filters
        return branches if filters.empty?

        branches.select { |branch| filters.any? { |matches| matches.call(branch) } }
      end

      def active_filters
        filters = {
          merged: ->(branch) { branch.merged && !branch.default? },
          gone: lambda(&:upstream_gone?),
          stale: ->(branch) { branch.stale?(options[:stale]) }
        }
        filters.select { |name, _filter| options[name] }.values
      end

      def table(branches)
        return 'No branches match.' if branches.empty?

        width = branches.map { |branch| branch.name.length }.max
        branches.map { |branch| row(branch, width) }.join("\n")
      end

      def row(branch, width)
        marker = branch.current? ? '*' : ' '
        columns = [
          "#{marker} #{branch.name.ljust(width)}",
          age(branch.last_commit_at).ljust(12),
          status(branch).ljust(22),
          branch.last_commit_subject
        ]
        columns.join('  ').rstrip
      end

      def status(branch)
        {
          'default' => branch.default?,
          'merged' => branch.merged && !branch.default?,
          'gone' => branch.upstream_gone?,
          "ahead #{branch.ahead}" => branch.ahead.positive?,
          "behind #{branch.behind}" => branch.behind.positive?
        }.select { |_label, shown| shown }.keys.join(', ')
      end

      def age(time)
        days = ((Time.now - time) / 86_400).floor
        return 'today' if days < 1

        days == 1 ? '1 day ago' : "#{days} days ago"
      end
    end
  end
end
