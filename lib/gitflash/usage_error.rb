# frozen_string_literal: true

module Gitflash
  # Raised for invalid arguments or when input is needed but no terminal is available
  class UsageError < Error
    def initialize(message = nil, code: 'invalid_usage', plan: nil)
      super
    end

    def exit_code
      2
    end
  end
end
