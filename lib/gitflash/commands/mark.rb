# frozen_string_literal: true

module Gitflash
  module Commands
    # Marks branches as agent or human work (`--owner`, default agent) or removes the mark
    # (`--clear`), so `gitflash clean --agent` knows which branches an agent created.
    # Without branch names the current branch is marked. Needs no confirmation: only a git
    # config key changes, and `--clear` or another `mark` reverses it.
    class Mark < Base
      def call(*names)
        names = names.uniq
        names = [current_branch!] if names.empty?
        check_branches!(names)

        previous = ownership.all
        plan = { branches: names, owner: owner }
        return planned(plan, "Would #{verb} #{names.join(', ')}") if ui.dry_run?

        apply(plan, previous)
      end

      private

      def ownership
        @ownership ||= Ownership.new
      end

      # The owner to set, nil for --clear
      def owner
        given = options[:owner]
        if options[:clear]
          usage_error!('invalid_options', 'Use either --owner or --clear, not both') if given
          return nil
        end
        return 'agent' if given.nil?
        return given if Ownership::OWNERS.include?(given)

        usage_error!('invalid_options', "Unknown owner '#{given}' (use agent or human)")
      end

      def verb
        options[:clear] ? 'clear the mark of' : "mark as #{owner}"
      end

      def current_branch!
        repo.current_branch || usage_error!('invalid_usage',
                                            'HEAD is detached: pass the branch to mark')
      end

      def check_branches!(names)
        known = repo.branches.map(&:name)
        unknown = names.reject { |name| known.include?(name) }
        usage_error!('unknown_branch', "Unknown branch: #{unknown.join(', ')}") if unknown.any?
      end

      def apply(plan, previous)
        plan[:branches].each { |name| write(name, plan[:owner]) }
        rows = plan[:branches].map { |name| row(name, plan[:owner], previous[name]) }
        status = rows.all? { |entry| entry[:owner] == entry[:previous] } ? 'noop' : 'done'
        ui.report(status: status, plan: plan, result: { branches: rows }, text: text(rows))
      end

      def write(name, owner)
        owner ? ownership.mark(name, owner) : ownership.clear(name)
      end

      def row(name, owner, previous)
        { branch: name, owner: owner, previous: previous }
      end

      def text(rows)
        rows.map { |row| line(row) }.join("\n")
      end

      def line(row)
        if row[:owner] == row[:previous]
          return "#{row[:branch]} is already #{row[:owner] || 'unmarked'}"
        end
        return "Cleared the mark of #{row[:branch]} (was #{row[:previous]})" unless row[:owner]

        "Marked #{row[:branch]} as #{row[:owner]}"
      end
    end
  end
end
