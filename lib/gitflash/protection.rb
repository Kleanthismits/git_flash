# frozen_string_literal: true

module Gitflash
  # Branches gitflash never deletes: the current and default branch, the usual long-lived
  # branches (`main`, `master`, `develop`, `development`, `trunk`, `release/*`), names matching
  # `protected` in the settings, and any branch checked out in a worktree. The long-lived names
  # count even when the default branch is something else or unknown: in a git-flow repository
  # `develop` is merged into `main` after every release and would otherwise look done.
  class Protection
    NAMES = %w[main master develop development trunk].freeze
    PATTERNS = %w[release/*].freeze

    def initialize(config:, checked_out: [])
      @config = config
      @checked_out = checked_out
    end

    def protected?(branch)
      branch.current? || branch.default? || long_lived?(branch.name) ||
        @config.protected?(branch.name) || @checked_out.include?(branch.name)
    end

    def long_lived?(name)
      NAMES.include?(name) || PATTERNS.any? { |pattern| File.fnmatch?(pattern, name) }
    end
  end
end
