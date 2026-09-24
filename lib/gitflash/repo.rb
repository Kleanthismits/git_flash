# frozen_string_literal: true

module Gitflash
  # Reads and changes the git repository in the current working directory.
  # All git access goes through this class; it never prompts or prints.
  class Repo
    SEPARATOR = "\x1f"
    BRANCH_FORMAT = %w[
      refname:short objectname:short HEAD upstream:short upstream:track,nobracket
      committerdate:iso-strict authorname subject
    ].map { |field| "%(#{field})" }.join('%1f')
    COMMIT_FORMAT = %w[%h %s %an %cI].join('%x1f')
    COMMITS_LIMIT = 100
    FALLBACK_DEFAULT_BRANCHES = %w[main master].freeze

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

      @default_branch = default_ref&.delete_prefix('origin/')
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
      stdout, _stderr, success = @bash.capture('git', 'rev-parse', '--verify', '--quiet',
                                               "#{ref}^{commit}")
      success ? stdout.strip : nil
    end

    def checkout(branch)
      run('git', 'checkout', branch, '--')
    end

    def delete_branch(branch, force: false)
      run('git', 'branch', force ? '-D' : '-d', branch)
    end

    def reset(commit, mode:)
      run('git', 'reset', "--#{mode}", commit, '--')
    end

    private

    def branch_lines
      @branch_lines ||= @bash.exec('git', 'for-each-ref', "--format=#{BRANCH_FORMAT}",
                                   'refs/heads/')
                             .each_line(chomp: true).reject(&:empty?)
    end

    # Ref used to check merge status: origin/HEAD's target, else a local main/master
    def default_ref
      return @default_ref if defined?(@default_ref)

      @default_ref = remote_default_ref || local_default_branch
    end

    def remote_default_ref
      ref = @bash.exec('git', 'symbolic-ref', '--quiet', '--short',
                       'refs/remotes/origin/HEAD').strip
      ref.empty? ? nil : ref
    rescue Git::CommandError
      nil
    end

    def local_default_branch
      names = branch_lines.map { |line| line.split(SEPARATOR, 2).first }
      FALLBACK_DEFAULT_BRANCHES.find { |name| names.include?(name) }
    end

    def merged_branch_names
      return nil unless default_ref

      @bash.exec('git', 'for-each-ref', "--merged=#{default_ref}", '--format=%(refname:short)',
                 'refs/heads/')
           .each_line(chomp: true).to_set
    end

    def run(*)
      stdout, stderr, success = @bash.capture(*)
      Result.new(success: success,
                 output: [stdout, stderr].map(&:strip).reject(&:empty?).join("\n"))
    end
  end
end
