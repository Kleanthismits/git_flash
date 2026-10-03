# frozen_string_literal: true

module Gitflash
  module Git
    class CommandError < Gitflash::Error
      def initialize(message = nil, code: 'git_failed', plan: nil)
        super
      end
    end
  end
end
