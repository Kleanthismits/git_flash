# frozen_string_literal: true

require 'thor'

module Gitflash
  # `gitflash worktree ...` (alias `wt`): worktrees for parallel agent work
  class WorktreeCli < Thor
    include CommandRunner

    namespace 'worktree'

    def self.exit_on_failure?
      true
    end

    desc 'list', 'List worktrees with branch, dirty and merge state'
    long_desc <<~TEXT
      Lists every worktree of the repository: absolute path, branch, HEAD, whether it has
      uncommitted changes, ahead/behind counts, whether its branch is merged into the default
      branch, lock state and whether its directory is missing.

      Agents use the absolute paths from `--json`; no directory switching is needed.

      Accepts the global --json option after the subcommand: gitflash wt list --json
    TEXT
    def list
      run_command('worktree list', Commands::WorktreeList)
    end
  end
end
