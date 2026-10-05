# frozen_string_literal: true

module Gitflash
  # Saved repository state that `gitflash undo` can restore.
  #
  # scope          parts of the state that undo restores: branches, head, worktree, stashes
  # head           { branch:, sha: } of HEAD; branch is nil on a detached HEAD, sha nil before
  #                the first commit
  # branches       { name => sha } of the recorded local branches
  # stashes        stash commits, newest first
  # index          commit whose tree is the staged state, nil when the tree was clean
  # worktree       commit whose tree is the working tree including untracked files (not
  #                ignored ones), nil when the tree was clean
  # skipped_files  untracked files left out because they were too large
  Snapshot = Data.define(
    :id, :created_at, :reason, :scope, :worktree_path, :head, :branches, :stashes,
    :index, :worktree, :skipped_files
  ) do
    def self.from_h(hash)
      new(
        id: hash['id'], created_at: hash['created_at'], reason: hash['reason'],
        scope: hash['scope'], worktree_path: hash['worktree_path'],
        head: { branch: hash.dig('head', 'branch'), sha: hash.dig('head', 'sha') },
        branches: hash['branches'] || {}, stashes: hash['stashes'] || [],
        index: hash['index'], worktree: hash['worktree'], skipped_files: hash['skipped_files'] || []
      )
    end

    def scope?(part)
      scope.include?(part)
    end

    # Commits the snapshot must keep reachable
    def object_ids
      ([head[:sha], index, worktree] + branches.values + stashes).compact.uniq
    end

    # Everything except id, time and reason, to detect an unchanged repository
    def state
      to_h.except(:id, :created_at, :reason)
    end

    def to_h
      super.merge(branches: branches.transform_keys(&:to_s))
    end
  end
end
