# frozen_string_literal: true

module Gitflash
  # Built-in defaults, files and the check each key must pass
  module ConfigKeys
    REPO_FILE = '.gitflash.yml'
    USER_FILE = File.join('.config', 'gitflash.yml')
    DEFAULT_WORKTREE_DIR = '../%<repo>s.worktrees/%<branch>s'
    DEFAULTS = {
      'protected' => [], 'stale_days' => 30, 'worktree_dir' => DEFAULT_WORKTREE_DIR,
      'snapshot_exclude' => []
    }.freeze
    PLACEHOLDERS = ['%<repo>s', '%<branch>s'].freeze
    MAX_TEMPLATE_LENGTH = 512
    CHECKS = {
      'protected' => [->(v) { v.is_a?(Array) && v.all? { |pattern| branch_pattern?(pattern) } },
                      'a list of branch name patterns (no spaces, control characters, ~, ^ or :)'],
      'stale_days' => [->(v) { v.is_a?(Integer) && v.positive? }, 'a positive whole number'],
      'worktree_dir' => [->(v) { template?(v) },
                         'a path of up to 512 characters that uses only %<repo>s and %<branch>s'],
      'snapshot_exclude' => [->(v) { v.is_a?(Array) && v.all?(String) },
                             'a list of file name patterns']
    }.freeze

    # Whether a template resolves inside the parent of the main checkout, for any repository and
    # branch name (branch names cannot hold `..`)
    def self.contained?(template)
      return false if template.start_with?('/', '~')

      root = '/parent/repo'
      path = template.gsub('%<repo>s', 'repo').gsub('%<branch>s', 'branch')
      File.expand_path(path, root).start_with?("#{File.dirname(root)}/")
    end

    # A pattern that can match a branch name: characters git refuses in branch names, such as a
    # space at either end, would make it match nothing without any warning
    def self.branch_pattern?(value)
      value.is_a?(String) && !value.empty? && !value.match?(/[\x00-\x20\x7F~^:\\]/)
    end

    # A path template: the two placeholders are the only `%` directives, so a width such as
    # `%<repo>999999999s` can never make Ruby build a huge string
    def self.template?(value)
      return false unless value.is_a?(String)
      return false if value.empty? || value.length > MAX_TEMPLATE_LENGTH

      !PLACEHOLDERS.reduce(value) { |rest, placeholder| rest.gsub(placeholder, '') }.include?('%')
    end

    # A repository's worktree_dir passed a check on the text alone; a symbolic link in the
    # repository (`wt-link -> /elsewhere`) could still lead out, so the real location of the
    # deepest existing directory on the way must stay next to the main checkout too
    def self.check_contained!(path, root)
      parent = File.realpath(File.dirname(root))
      existing = path
      existing = File.dirname(existing) until File.exist?(existing)
      real = File.join(File.realpath(existing), path.delete_prefix(existing))
      return if real.start_with?("#{parent}/")

      raise UsageError.new("worktree_dir in #{REPO_FILE} leads to #{real}, outside " \
                           "#{parent}; set worktree_dir in ~/.config/gitflash.yml to use it",
                           code: 'invalid_config')
    end
  end
end
