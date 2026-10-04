# frozen_string_literal: true

require 'fileutils'
require 'tempfile'

module Gitflash
  # Reads the repository state a snapshot saves and writes the needed git objects.
  # Never changes branches, the index or the working tree.
  class StateCapture
    MAX_UNTRACKED_FILE_BYTES = 50 * 1024 * 1024
    ADD_BATCH_SIZE = 500
    IDENTITY = {
      'GIT_AUTHOR_NAME' => 'gitflash', 'GIT_AUTHOR_EMAIL' => 'gitflash@localhost',
      'GIT_COMMITTER_NAME' => 'gitflash', 'GIT_COMMITTER_EMAIL' => 'gitflash@localhost'
    }.freeze
    # Content commits get a fixed date so the same content always gives the same sha
    FIXED_DATE = {
      'GIT_AUTHOR_DATE' => '1970-01-01T00:00:00Z', 'GIT_COMMITTER_DATE' => '1970-01-01T00:00:00Z'
    }.freeze

    def initialize(bash: Git::BashCommand)
      @bash = bash
    end

    # Snapshot fields except id, time and reason. `branch_names` nil records every branch.
    def call(scope, branch_names)
      head_sha = rev('HEAD')
      state = {
        scope: Snapshots::SCOPES & scope, worktree_path: git('rev-parse', '--show-toplevel'),
        head: { branch: current_branch, sha: head_sha },
        branches: scope.include?('branches') ? branch_tips(branch_names) : {},
        stashes: scope.include?('stashes') ? try('stash', 'list', '--format=%H').to_s.split : [],
        index: nil, worktree: nil, skipped_files: []
      }
      state.merge!(worktree(head_sha)) if scope.include?('worktree') && dirty?
      state
    end

    def commit_tree(tree, parents:, message:, env: {})
      parent_args = parents.uniq.flat_map { |sha| ['-p', sha] }
      git('commit-tree', tree, *parent_args, '-m', message, env: IDENTITY.merge(env))
    end

    def empty_tree
      @empty_tree ||= git('mktree')
    end

    private

    def git(*, env: {})
      @bash.exec('git', *, env: env).strip
    end

    # Stripped stdout, or nil when the command fails
    def try(*)
      stdout, _stderr, success = @bash.capture('git', *)
      success ? stdout.strip : nil
    end

    def rev(ref)
      try('rev-parse', '--verify', '--quiet', "#{ref}^{commit}")
    end

    def current_branch
      ref = try('symbolic-ref', '--quiet', 'HEAD')
      ref&.delete_prefix(Repo::HEADS)
    end

    def branch_tips(names)
      tips = Branch.parse_tips(git('for-each-ref', "--format=#{Branch::TIPS_FORMAT}", Repo::HEADS))
      names.nil? ? tips : tips.slice(*names)
    end

    def dirty?
      !git('status', '--porcelain', '--untracked-files=all').empty?
    end

    def worktree(head_sha)
      parents = [head_sha].compact
      index_tree = try('write-tree') # nil while a merge conflict is unresolved
      tree, skipped = worktree_tree
      {
        index: index_tree && content_commit(index_tree, parents, 'gitflash index'),
        worktree: content_commit(tree, parents, 'gitflash worktree'),
        skipped_files: skipped
      }
    end

    def content_commit(tree, parents, message)
      commit_tree(tree, parents: parents, message: message, env: FIXED_DATE)
    end

    # Tree of the working tree, built in a temporary copy of the index so the real one is untouched
    def worktree_tree
      top = git('rev-parse', '--show-toplevel')
      Tempfile.create('gitflash-index', File.expand_path(git('rev-parse', '--git-dir'))) do |file|
        file.close
        real_index = File.expand_path(git('rev-parse', '--git-path', 'index'))
        FileUtils.cp(real_index, file.path) if File.exist?(real_index)
        env = { 'GIT_INDEX_FILE' => file.path }

        git('-C', top, 'add', '--update', env: env)
        skipped = add_untracked(top, env)
        [git('write-tree', env: env), skipped]
      end
    end

    # Adds untracked files that are not ignored; returns the ones skipped for their size
    def add_untracked(top, env)
      paths = git('-C', top, 'ls-files', '-z', '--others', '--exclude-standard')
              .split("\0").reject { |path| path.end_with?('/') }
      small, large = paths.partition do |path|
        File.lstat(File.join(top, path)).size <= MAX_UNTRACKED_FILE_BYTES
      end
      small.each_slice(ADD_BATCH_SIZE) { |batch| git('-C', top, 'add', '--', *batch, env: env) }
      large
    end
  end
end
