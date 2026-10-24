# frozen_string_literal: true

require 'yaml'

module Gitflash
  # Settings from `.gitflash.yml` in the main checkout and `~/.config/gitflash.yml`.
  # Precedence: repository file, then user file, then built-in defaults; for `worktree_dir` the
  # user file wins, since it decides where on the user's disk checkouts are written.
  # Command-line flags are applied by the commands themselves and win over all of these.
  # An unknown key or a value of the wrong type raises a UsageError, so a typo never goes unnoticed.
  Config = Data.define(:protected_patterns, :stale_days, :worktree_dir, :worktree_dir_from_repo,
                       :snapshot_exclude) do
    # `root` is the main checkout; `home` is where the user file lives. The repository file wins
    # key by key, except `protected`: both files add patterns, so a repository can protect more
    # branches but never remove what the user protects; and `worktree_dir`, where the user file
    # wins. A cloned repository's file may only place worktrees next to the main checkout.
    def self.load(root:, home: Dir.home)
      user = read(File.join(home, ConfigKeys::USER_FILE))
      repo = read(File.join(root, ConfigKeys::REPO_FILE), repository: true)
      values = ConfigKeys::DEFAULTS.merge(user).merge(repo)
      new(protected_patterns: both([user, repo], 'protected'), stale_days: values['stale_days'],
          snapshot_exclude: both([user, repo], 'snapshot_exclude'), **worktree_dir_of(user, repo))
    end

    # Lists that both files add to
    def self.both(layers, key)
      layers.flat_map { |layer| layer.fetch(key, []) }.uniq
    end
    private_class_method :both

    # The user file wins for worktree_dir; a value from the repository is checked again where
    # it leads (see #check_contained!)
    def self.worktree_dir_of(user, repo)
      from_repo = !user.key?('worktree_dir') && repo.key?('worktree_dir')
      dir = from_repo ? repo['worktree_dir'] : user.fetch('worktree_dir', ConfigKeys::DEFAULT_WORKTREE_DIR)
      { worktree_dir: dir,
        worktree_dir_from_repo: from_repo }
    end
    private_class_method :worktree_dir_of

    def self.defaults
      new(protected_patterns: [], stale_days: 30, worktree_dir: ConfigKeys::DEFAULT_WORKTREE_DIR,
          worktree_dir_from_repo: false, snapshot_exclude: [])
    end

    def self.read(path, repository: false)
      return {} unless File.file?(path)

      reject_duplicate_keys!(path)
      data = YAML.safe_load_file(path) || {}
      validate!(data, path)
      check_repository_dir!(data['worktree_dir'], path) if repository
      data
    rescue Psych::Exception, SystemCallError, IOError => e
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

    # A repository's file comes with the clone, so its worktree_dir must stay next to the main
    # checkout: relative, no `~`, and not climbing above the main checkout's parent
    def self.check_repository_dir!(template, path)
      return if template.nil? || ConfigKeys.contained?(template)

      raise invalid(path, "'worktree_dir' must be a relative path that stays next to the " \
                          'repository (set other places in ~/.config/gitflash.yml)')
    end
    private_class_method :check_repository_dir!

    def self.invalid(path, problem)
      UsageError.new("#{path} #{problem}", code: 'invalid_config')
    end
    private_class_method :invalid

    # True when the branch name matches a configured pattern (shell-style `*` and `?`)
    def protected?(name)
      protected_patterns.any? { |pattern| File.fnmatch?(pattern, name) }
    end

    # True when an untracked file must stay out of snapshots: the pattern matches its path or
    # its name (`*.pem`, `.env*`, `secrets/*`)
    def snapshot_excluded?(path)
      flags = File::FNM_PATHNAME | File::FNM_DOTMATCH
      snapshot_exclude.any? do |pattern|
        File.fnmatch?(pattern, path, flags) || File.fnmatch?(pattern, File.basename(path), flags)
      end
    end

    # Directory for a new worktree. `%<repo>s` and `%<branch>s` are replaced as plain text; a
    # relative path is resolved against the main checkout. Slashes in a branch name stay as
    # folders.
    def worktree_path(root:, branch:)
      path = worktree_dir.gsub('%<repo>s') { File.basename(root) }.gsub('%<branch>s') { branch }
      path = File.expand_path(path, root)
      check_contained!(path, root) if worktree_dir_from_repo
      path
    end

    private

    # A repository's worktree_dir passed a check on the text alone; a symbolic link in the
    # repository (`wt-link -> /elsewhere`) could still lead out, so the real location of the
    # deepest existing directory on the way must stay next to the main checkout too
    def check_contained!(path, root)
      parent = File.realpath(File.dirname(root))
      existing = path
      existing = File.dirname(existing) until File.exist?(existing)
      real = File.join(File.realpath(existing), path.delete_prefix(existing))
      return if real.start_with?("#{parent}/")

      raise UsageError.new("worktree_dir in #{ConfigKeys::REPO_FILE} leads to #{real}, outside " \
                           "#{parent}; set worktree_dir in ~/.config/gitflash.yml to use it",
                           code: 'invalid_config')
    end
  end
end
