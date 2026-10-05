# frozen_string_literal: true

require 'yaml'

module Gitflash
  # Settings from `.gitflash.yml` in the main checkout and `~/.config/gitflash.yml`.
  # Precedence: repository file, then user file, then built-in defaults.
  # Command-line flags are applied by the commands themselves and win over all of these.
  # An unknown key or a value of the wrong type raises a UsageError, so a typo never goes unnoticed.
  Config = Data.define(:protected_patterns, :stale_days, :worktree_dir) do
    # `root` is the main checkout; `home` is where the user file lives
    def self.load(root:, home: Dir.home)
      values = [File.join(home, ConfigKeys::USER_FILE), File.join(root, ConfigKeys::REPO_FILE)]
               .map { |path| read(path) }
               .reduce(ConfigKeys::DEFAULTS) { |merged, layer| merged.merge(layer) }
      new(protected_patterns: values['protected'], stale_days: values['stale_days'],
          worktree_dir: values['worktree_dir'])
    end

    def self.defaults
      new(protected_patterns: [], stale_days: 30, worktree_dir: ConfigKeys::DEFAULT_WORKTREE_DIR)
    end

    def self.read(path)
      return {} unless File.file?(path)

      reject_duplicate_keys!(path)
      data = YAML.safe_load_file(path) || {}
      validate!(data, path)
      data
    rescue Psych::Exception => e
      raise invalid(path, "cannot be read (#{e.message.lines.first.strip})")
    end
    private_class_method :read

    # A YAML loader keeps only the last of two equal keys, which could drop a `protected` list
    def self.reject_duplicate_keys!(path)
      root = Psych.parse_file(path)
      return unless root

      duplicate = duplicate_key(root)
      raise invalid(path, "has the key '#{duplicate}' more than once") if duplicate
    end
    private_class_method :reject_duplicate_keys!

    def self.duplicate_key(node)
      own = node.is_a?(Psych::Nodes::Mapping) ? own_duplicate(node) : nil
      own || (node.children || []).filter_map { |child| duplicate_key(child) }.first
    end
    private_class_method :duplicate_key

    def self.own_duplicate(mapping)
      keys = mapping.children.each_slice(2).filter_map do |key, _value|
        key.value if key.respond_to?(:value)
      end
      keys.tally.find { |_key, count| count > 1 }&.first
    end
    private_class_method :own_duplicate

    def self.validate!(data, path)
      raise invalid(path, 'must be a mapping') unless data.is_a?(Hash)

      unknown = data.keys - ConfigKeys::DEFAULTS.keys
      raise invalid(path, "has unknown keys: #{unknown.join(', ')}") if unknown.any?

      check_types!(data, path)
    end
    private_class_method :validate!

    def self.check_types!(data, path)
      data.each do |key, value|
        check, expected = ConfigKeys::CHECKS.fetch(key)
        raise invalid(path, "'#{key}' must be #{expected}") unless check.call(value)
      end
    end
    private_class_method :check_types!

    def self.invalid(path, problem)
      UsageError.new("#{path} #{problem}", code: 'invalid_config')
    end
    private_class_method :invalid

    # True when the branch name matches a configured pattern (shell-style `*` and `?`)
    def protected?(name)
      protected_patterns.any? { |pattern| File.fnmatch?(pattern, name) }
    end

    # Directory for a new worktree. `%{repo}` and `%{branch}` are replaced; a relative path
    # is resolved against the main checkout. Slashes in a branch name stay as folders.
    def worktree_path(root:, branch:)
      path = format(worktree_dir, repo: File.basename(root), branch: branch)
      File.expand_path(path, root)
    end
  end
end
