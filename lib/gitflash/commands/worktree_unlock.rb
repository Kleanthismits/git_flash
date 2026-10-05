# frozen_string_literal: true

module Gitflash
  module Commands
    # Unlocks a worktree; see WorktreeLock
    class WorktreeUnlock < WorktreeLock
      private

      def lock? = false
    end
  end
end
