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

      def require_interactive!(message)
        usage_error!('input_required', message) unless ui.interactive?
      end

      def usage_error!(code, message)
        raise UsageError.new(message, code: code)
      end

      def git_error!(command, result)
        raise Error.new("git #{command} failed:\n#{result.output}", code: 'git_failed')
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
