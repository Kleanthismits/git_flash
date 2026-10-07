# frozen_string_literal: true

module Gitflash
  # Who created a branch: `agent` or `human`. Stored in git config as
  # `branch.<name>.gitflash-owner`, which git removes together with the branch.
  # A branch without a mark counts as human work and is never selected for automatic cleanup.
  class Ownership
    OWNERS = %w[agent human].freeze
    SUFFIX = '.gitflash-owner'
    PREFIX = 'branch.'

    def initialize(bash: Git::BashCommand)
      @bash = bash
    end

    # { branch name => owner } for every marked branch
    def all
      stdout, _stderr, success = @bash.capture('git', 'config', '--local', '-z', '--get-regexp',
                                               '^branch\..+\.gitflash-owner$')
      return {} unless success

      stdout.split("\0").filter_map { |entry| parse(entry) }.to_h
    end

    # The branches with their `owner` set from the marks
    def annotate(branches)
      owners = all
      branches.map { |branch| branch.with(owner: owners[branch.name]) }
    end

    def mark(branch, owner)
      unless OWNERS.include?(owner)
        raise UsageError.new("Unknown owner '#{owner}' (use #{OWNERS.join(' or ')})",
                             code: 'invalid_usage')
      end

      @bash.exec('git', 'config', '--local', key(branch), owner)
    end

    # Removes the mark; a branch without a mark is already unmarked
    def clear(branch)
      @bash.capture('git', 'config', '--local', '--unset', key(branch))
    end

    private

    def key(branch)
      "#{PREFIX}#{branch}#{SUFFIX}"
    end

    # Entry from `-z`: "branch.<name>.gitflash-owner\nvalue". Branch names may contain dots.
    def parse(entry)
      full_key, value = entry.split("\n", 2)
      return nil unless full_key.start_with?(PREFIX) && full_key.end_with?(SUFFIX)

      [full_key.delete_prefix(PREFIX).delete_suffix(SUFFIX), value.to_s.strip]
    end
  end
end
