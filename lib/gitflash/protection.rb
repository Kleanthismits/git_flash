# frozen_string_literal: true

module Gitflash
  # Branches gitflash never deletes: the current and default branch, `main`, `master`, names
  # matching `protected` in the settings, and any branch checked out in a worktree.
  class Protection
    NAMES = %w[main master].freeze

    def initialize(config:, checked_out: [])
      @config = config
      @checked_out = checked_out
    end

    def protected?(branch)
      branch.current? || branch.default? || NAMES.include?(branch.name) ||
        @config.protected?(branch.name) || @checked_out.include?(branch.name)
    end
  end
end
