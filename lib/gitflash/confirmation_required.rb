# frozen_string_literal: true

module Gitflash
  # Raised when a destructive command runs without a terminal and without --yes
  class ConfirmationRequired < Error
    def exit_code
      2
    end
  end
end
