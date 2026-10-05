# frozen_string_literal: true

module Gitflash
  # A checkout of the repository as reported by `git worktree list --porcelain`.
  # `branch` is nil for a detached HEAD. `missing` means the directory is gone (git calls it
  # prunable). `dirty` is nil when it cannot be known (missing directory or bare repository).
  # ahead, behind, merged and owner are those of the branch, nil without a branch.
  Worktree = Data.define(
    :path, :head, :branch, :main, :bare, :locked, :lock_reason, :missing,
    :dirty, :ahead, :behind, :merged, :owner
  ) do
    alias_method :main?, :main
    alias_method :locked?, :locked
    alias_method :missing?, :missing
    alias_method :dirty?, :dirty
  end
end
