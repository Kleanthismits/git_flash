# frozen_string_literal: true

module Gitflash
  # Raised when a destructive command runs without a terminal and without --yes.
  # Carries the plan so the caller can review it and re-run with --yes, or, for a change
  # gitflash undo cannot revert, the token to pass to --confirm.
  class ConfirmationRequired < Error
    attr_reader :confirm_token

    def initialize(message = nil, plan: nil, confirm_token: nil)
      super(message, code: 'confirmation_required', plan: plan)
      @confirm_token = confirm_token
    end

    def exit_code
      2
    end

    def status
      'confirmation_required'
    end
  end
end
