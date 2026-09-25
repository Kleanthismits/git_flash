# frozen_string_literal: true

module Gitflash
  # Raised when a destructive command runs without a terminal and without --yes.
  # Carries the plan so the caller can review it and re-run with --yes.
  class ConfirmationRequired < Error
    def initialize(message = nil, plan: nil)
      super(message, code: 'confirmation_required', plan: plan)
    end

    def exit_code
      2
    end

    def status
      'confirmation_required'
    end
  end
end
