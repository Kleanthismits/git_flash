# frozen_string_literal: true

module Gitflash
  # Raised for invalid arguments or when input is needed but no terminal is available
  class UsageError < Error
    def exit_code
      2
    end
  end
end
