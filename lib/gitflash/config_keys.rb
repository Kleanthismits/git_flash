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
    CHECKS = {
      'protected' => [->(v) { v.is_a?(Array) && v.all?(String) },
                      'a list of branch name patterns'],
      'stale_days' => [->(v) { v.is_a?(Integer) && v.positive? }, 'a positive whole number'],
      'worktree_dir' => [->(v) { v.is_a?(String) && !v.empty? }, 'a non-empty string']
    }.freeze
  end
end
