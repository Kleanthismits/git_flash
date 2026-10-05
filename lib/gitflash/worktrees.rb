# frozen_string_literal: true

module Gitflash
  # The worktrees of the repository. All parsing of `git worktree` output lives here;
  # callers get Worktree records and never see porcelain text.
  class Worktrees
    def initialize(repo:, bash: Git::BashCommand)
      @repo = repo
      @bash = bash
    end

    # Every worktree, main checkout first, each with its dirty state and branch status
    def list
      branches = @repo.branches(merged_status: true).to_h { |branch| [branch.name, branch] }
      records.each_with_index.map { |record, index| build(record, index.zero?, branches) }
    end

    # How `add` will get the branch: an existing local branch, a new local branch that tracks
    # origin/<branch>, or a new branch (from HEAD or `start`)
    def source_for(branch)
      return :existing if local_branch?(branch)

      remote_branch?(branch) ? :remote : :new
    end

    # Creates the worktree and returns the git Result. `start` only applies to a new branch.
    def add(path, branch:, source:, start: nil)
      args = case source
             when :existing then [path, branch]
             when :remote then ['--track', '-b', branch, '--', path, "origin/#{branch}"]
             else ['-b', branch, '--', path, *start]
             end
      args.unshift('--') if source == :existing
      run('worktree', 'add', *args)
    end

    # Adds a worktree again for undo: on `branch` (created at `create_at` when it no longer
    # exists) or detached at `detach_at`. A directory git still lists as missing is reused.
    def attach(path, branch: nil, create_at: nil, detach_at: nil)
      force = registered_missing?(path) ? ['--force'] : []
      return run('worktree', 'add', *force, '--detach', '--', path, detach_at) if detach_at
      return run('worktree', 'add', *force, '--', path, branch) if local_branch?(branch)

      run('worktree', 'add', *force, '-b', branch, '--', path, create_at)
    end

    # Ignored files and directories (a directory counts once) of a worktree, which snapshots
    # do not save. Empty when the directory is missing.
    def ignored(path)
      stdout, _stderr, success = @bash.capture('git', '-C', path, 'ls-files', '-z', '--others',
                                               '--ignored', '--exclude-standard', '--directory')
      success ? stdout.split("\0") : []
    end

    def lock(path, reason: nil)
      run('worktree', 'lock', *(reason ? ['--reason', reason] : []), '--', path)
    end

    def unlock(path) = run('worktree', 'unlock', '--', path)

    # A locked worktree needs `force`
    def move(path, destination, force: false)
      run('worktree', 'move', *(force ? %w[--force --force] : []), '--', path, destination)
    end

    def prune
      run('worktree', 'prune')
    end

    # Removes a worktree directory. A locked one needs `force`, a dirty one too.
    def remove(path, force: false)
      run('worktree', 'remove', *(force ? %w[--force --force] : []), '--', path)
    end

    private

    def registered_missing?(path)
      wanted = normalized_path(path)
      list.any? { |worktree| worktree.missing? && normalized_path(worktree.path) == wanted }
    end

    # Same directory under any spelling (symlinked parents); the directory itself may not exist
    def normalized_path(path)
      File.join(File.realpath(File.dirname(path)), File.basename(path))
    rescue Errno::ENOENT
      File.expand_path(path)
    end

    def local_branch?(branch) = ref?("#{Repo::HEADS}#{branch}")

    def remote_branch?(branch) = ref?("#{Repo::REMOTE_HEAD}#{branch}")

    def ref?(full_name)
      _stdout, _stderr, success = @bash.capture('git', 'show-ref', '--verify', '--quiet', full_name)
      success
    end

    def run(*)
      stdout, stderr, success = @bash.capture('git', *)
      Result.new(success: success,
                 output: [stdout, stderr].map(&:strip).reject(&:empty?).join("\n"))
    end

    def records
      output = @bash.exec('git', 'worktree', 'list', '--porcelain', '-z')
      # `-z` ends every attribute with NUL and every record with an extra NUL, so paths with
      # newlines and lock reasons come back as written
      output.split("\0\0").reject(&:empty?).map { |block| parse(block) }
    end

    def parse(block)
      block.split("\0").reject(&:empty?).to_h do |attribute|
        key, value = attribute.split(' ', 2)
        [key, value || true]
      end
    end

    def build(record, main, branches)
      branch = record['branch']&.delete_prefix(Repo::HEADS)
      Worktree.new(**state(record, main), branch: branch, **branch_status(branches[branch]))
    end

    def state(record, main)
      path = record.fetch('worktree')
      missing = record.key?('prunable') || !File.directory?(path)
      bare = record.key?('bare')
      { path: path, head: record['HEAD'], main: main, bare: bare, missing: missing,
        locked: record.key?('locked'), lock_reason: lock_reason(record['locked']),
        dirty: dirty(path, missing, bare) }
    end

    def branch_status(info)
      { ahead: info&.ahead, behind: info&.behind, merged: info&.merged, owner: info&.owner }
    end

    def lock_reason(value)
      value.is_a?(String) && !value.empty? ? value : nil
    end

    def dirty(path, missing, bare)
      return nil if missing || bare

      stdout, _stderr, success = @bash.capture('git', '-C', path, 'status', '--porcelain')
      success ? !stdout.strip.empty? : nil
    end
  end
end
