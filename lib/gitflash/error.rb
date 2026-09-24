# frozen_string_literal: true

module Gitflash
  # Base class for errors reported to the user.
  # `code` is a stable machine-readable identifier; `plan` is the planned change, if any.
  class Error < StandardError
    attr_reader :code, :plan

    def initialize(message = nil, code: 'failed', plan: nil)
      super(message)
      @code = code
      @plan = plan
    end

    def exit_code
      1
    end

    def status
      'error'
    end
  end
end
