# frozen_string_literal: true

module Gitflash
  # Reads and changes the git repository in the current working directory.
  # All git access goes through this class; it never prompts or prints.
  class Repo
    SEPARATOR = "\x1f"
    BRANCH_FORMAT = %w[
      refname objectname:short HEAD upstream:short upstream:track,nobracket
      committerdate:iso-strict authorname subject
    ].map { |field| "%(#{field})" }.join('%1f')
    COMMIT_FORMAT = %w[%h %s %an %cI].join('%x1f')
    COMMITS_LIMIT = 100
    FALLBACK_DEFAULT_BRANCHES = %w[main master].freeze
    HEADS = 'refs/heads/'
    REMOTE_HEAD = 'refs/remotes/origin/'

    def initialize(bash: Git::BashCommand)
      @bash = bash
    end

    def ensure_work_tree!
      inside = @bash.exec('git', 'rev-parse', '--is-inside-work-tree').strip == 'true'
      raise Error.new('Not a git repository', code: 'not_a_repository') unless inside
    rescue Git::CommandError
      raise Error.new('Not a git repository', code: 'not_a_repository')
    end

    # Local branches. With `merged_status: true` each branch also reports whether it is
    # merged into the default branch (one extra git call).
    def branches(merged_status: false)
      merged_names = merged_status ? merged_branch_names : nil
      branch_lines.map do |line|
        Branch.parse(line, default_branch: default_branch, merged_names: merged_names)
      end
    end

    def current_branch
      branches.find(&:current?)&.name
    end

    # The branch that origin/HEAD points to, else main or master when present locally
    def default_branch
      return @default_branch if defined?(@default_branch)

      @default_branch = branch_name(default_ref)
    end

    # Commits of the current branch, newest first. Empty for a branch without commits.
    def commits(limit: COMMITS_LIMIT)
      @bash.exec('git', 'log', "--max-count=#{limit}", "--format=#{COMMIT_FORMAT}")
           .each_line(chomp: true).reject(&:empty?).map { |line| Commit.parse(line) }
    rescue Git::CommandError
      []
    end

    # Full sha of a commit reference, or nil when it does not name a commit
    def resolve_commit(ref)
      return nil if ref.start_with?('-')

      stdout, _stderr, success = @bash.capture('git', 'rev-parse', '--verify', '--quiet',
                                               "#{ref}^{commit}")
      success ? stdout.strip : nil
    end

    # Uses `git switch`, which never discards changes or treats the name as a file path.
    # A name that starts with a dash is refused: a ref named like an option must not become one.
    def checkout(branch)
      refuse_option_like!(branch)
      run('git', 'switch', '--', branch)
    end

    def delete_branch(branch, force: false)
      run('git', 'branch', force ? '-D' : '-d', '--', branch)
    end

    def reset(commit, mode:)
      run('git', 'reset', "--#{mode}", commit, '--')
    end

    private

    # Removes only the prefix the ref starts with, so a branch named `refs/heads/x` keeps its name
    def branch_name(ref)
      return nil unless ref

      ref.delete_prefix(ref.start_with?(REMOTE_HEAD) ? REMOTE_HEAD : HEADS)
    end

    def refuse_option_like!(name)
      return unless name.start_with?('-')

      raise UsageError.new("Invalid branch name '#{name}'", code: 'invalid_usage')
    end

    def branch_lines
      @branch_lines ||= @bash.exec('git', 'for-each-ref', "--format=#{BRANCH_FORMAT}",
                                   HEADS)
                             .each_line(chomp: true).reject(&:empty?)
    end

    # Full ref used to check merge status: origin/HEAD's target, else a local main/master.
    # Full names are used throughout because short names change when a tag has the same name.
    def default_ref
      return @default_ref if defined?(@default_ref)

      @default_ref = remote_default_ref || local_default_branch
    end

    def remote_default_ref
      ref = @bash.exec('git', 'symbolic-ref', '--quiet', "#{REMOTE_HEAD}HEAD").strip
      ref.start_with?(REMOTE_HEAD) ? ref : nil
    rescue Git::CommandError
      nil
    end

    def local_default_branch
      names = branch_lines.map { |line| line.split(SEPARATOR, 2).first.delete_prefix(HEADS) }
      name = FALLBACK_DEFAULT_BRANCHES.find { |candidate| names.include?(candidate) }
      name && "#{HEADS}#{name}"
    end

    def merged_branch_names
      return nil unless default_ref

      @bash.exec('git', 'for-each-ref', "--merged=#{default_ref}", '--format=%(refname)', HEADS)
           .each_line(chomp: true).to_set { |ref| ref.delete_prefix(HEADS) }
    end

    def run(*)
      stdout, stderr, success = @bash.capture(*)
      Result.new(success: success,
                 output: [stdout, stderr].map(&:strip).reject(&:empty?).join("\n"))
    end
  end
end
