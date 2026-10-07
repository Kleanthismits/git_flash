# frozen_string_literal: true

module Gitflash
  # Brings back a worktree that was removed after a snapshot of it: adds the worktree again on
  # its branch (or detached HEAD) and restores its files. Branch tips are restored before the
  # worktree is added, so a branch deleted or moved since is checked out at its saved tip and its
  # files always match it.
  class WorktreeRevival
    def initialize(snapshot, repo:)
      @snapshot = snapshot
      @repo = repo
    end

    # Same shape as an undo plan, plus `recreate_worktree`
    def plan
      head = @snapshot.head
      { branches: Restore.new(@snapshot).plan[:branches],
        head: { from: nil, to: head[:branch] || head[:sha] },
        worktree: !@snapshot.worktree.nil?, stashes: [], snapshot: @snapshot.id,
        recreate_worktree: @snapshot.worktree_path }
    end

    def scope
      %w[branches]
    end

    def empty?
      false
    end

    # Returns nil on success or the failed step's Result
    def apply
      failure = Restore.new(@snapshot).apply(only: :branches)
      return failure if failure

      result = attach
      return result unless result.success?

      restore = Restore.new(@snapshot, bash: Git::InDirectory.new(@snapshot.worktree_path))
      restore.apply
    end

    private

    def attach
      worktrees = Worktrees.new(repo: @repo)
      path = @snapshot.worktree_path
      branch = @snapshot.head[:branch]
      sha = @snapshot.head[:sha]
      return worktrees.attach(path, detach_at: sha) unless branch

      worktrees.attach(path, branch: branch, create_at: sha)
    end
  end
end
