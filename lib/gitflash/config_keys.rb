# frozen_string_literal: true

module Gitflash
  # Built-in defaults, files and the check each key must pass
  module ConfigKeys
    REPO_FILE = '.gitflash.yml'
    USER_FILE = File.join('.config', 'gitflash.yml')
    DEFAULT_WORKTREE_DIR = '../%<repo>s.worktrees/%<branch>s'
    DEFAULTS = {
      'protected' => [], 'stale_days' => 30, 'worktree_dir' => DEFAULT_WORKTREE_DIR
    }.freeze
    PLACEHOLDERS = ['%<repo>s', '%<branch>s'].freeze
    MAX_TEMPLATE_LENGTH = 512
    CHECKS = {
      'protected' => [->(v) { v.is_a?(Array) && v.all?(String) },
                      'a list of branch name patterns'],
      'stale_days' => [->(v) { v.is_a?(Integer) && v.positive? }, 'a positive whole number'],
      'worktree_dir' => [->(v) { template?(v) },
                         'a path of up to 512 characters that uses only %<repo>s and %<branch>s']
    }.freeze

    # A path template: the two placeholders are the only `%` directives, so a width such as
    # `%<repo>999999999s` can never make Ruby build a huge string
    def self.template?(value)
      return false unless value.is_a?(String)
      return false if value.empty? || value.length > MAX_TEMPLATE_LENGTH

      !PLACEHOLDERS.reduce(value) { |rest, placeholder| rest.gsub(placeholder, '') }.include?('%')
    end
  end
end
