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

    # Why this worktree must not be removed, nil when it can go. `current` is true for the
    # worktree gitflash runs in. The main checkout and the current one are never removable.
    def removal_blocker(force:, current:)
      return "#{TerminalText.line(path)} is the main checkout" if main?
      return "#{TerminalText.line(path)} is the current worktree" if current

      in_use_blocker unless force || (missing? && !locked?)
    end

    def in_use_blocker
      return "#{TerminalText.line(path)} is locked (use --force)" if locked?

      "#{TerminalText.line(path)} has uncommitted changes (use --force)" if dirty? != false
    end
  end
end
