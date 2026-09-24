# frozen_string_literal: true

module Gitflash
  # Base class for errors reported to the user. `details` carries extra data for JSON output.
  class Error < StandardError
    attr_reader :details

    def initialize(message = nil, details: nil)
      super(message)
      @details = details
    end

    def exit_code
      1
    end
  end
end
