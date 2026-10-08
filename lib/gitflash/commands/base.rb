# frozen_string_literal: true

module Gitflash
  module Commands
    # Shared setup for commands. `call` returns the process exit status.
    class Base
      def initialize(repo:, ui:, options: {})
        @repo = repo
        @ui = ui
        @options = options
      end

      private

      attr_reader :repo, :ui, :options

      # A path from the repository, kept on one line of the output
      def shown(path) = TerminalText.line(path)

      def require_interactive!(message)
        usage_error!('input_required', message) unless ui.interactive?
      end

      def usage_error!(code, message)
        raise UsageError.new(message, code: code)
      end

      def git_error!(command, result)
        raise Error.new("git #{command} failed:\n#{result.output}", code: 'git_failed')
      end

      def config
        @config ||= Gitflash::Config.load(root: repo.main_root)
      end

      def snapshots
        @snapshots ||= Gitflash::Snapshots.new
      end

      # Saves the state a change is about to modify, so `gitflash undo` can restore it.
      # `dir` saves the HEAD and files of another worktree instead of the current one.
      def take_snapshot(reason, scope:, branches: nil, dir: nil)
        store = dir ? Gitflash::Snapshots.new(bash: Git::InDirectory.new(dir)) : snapshots
        store.create(reason: reason, scope: scope, branches: branches)
      end

      def planned(plan, text)
        ui.report(status: 'planned', plan: plan, text: text)
      end

      def cancelled(plan)
        ui.report(status: 'cancelled', plan: plan, text: 'Exited')
      end
    end
  end
end
