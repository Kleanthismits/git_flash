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
        raise UsageError, message unless ui.interactive?
      end
    end
  end
end
