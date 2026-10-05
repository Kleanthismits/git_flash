# frozen_string_literal: true

require 'thor'

module Gitflash
  # `gitflash worktree ...` (alias `wt`): worktrees for parallel agent work
  class WorktreeCli < Thor
    extend Configuration::Descriptions
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

    desc 'add BRANCH', 'Add a worktree for a branch (existing, remote or new)'
    long_desc <<~TEXT
      Adds a worktree for BRANCH. An existing local branch is checked out; a branch that exists
      only on origin is created to track it; any other name creates a new branch from HEAD
      (or from --from). New branches are marked as agent work so `gitflash clean` can find them.

      The directory defaults to ../<repo>.worktrees/<branch> (setting `worktree_dir` in
      .gitflash.yml changes it). The result lists the absolute path: use it, no directory
      switching is needed.

      Needs no confirmation. Accepts the global --json and --dry-run options after the
      subcommand: gitflash wt add feature --json
    TEXT
    option :path, type: :string, banner: 'DIR', desc: 'Directory for the worktree'
    option :from, type: :string, banner: 'REF', desc: 'Start a new branch from REF (default HEAD)'
    option :owner, type: :string, enum: Ownership::OWNERS,
                   desc: 'Mark a new branch as agent (default) or human work'
    def add(branch = nil)
      run_command('worktree add', Commands::WorktreeAdd, *[branch].compact)
    end

    desc 'lock WORKTREE', 'Lock a worktree so prune, remove and clean leave it alone'
    long_desc 'Locks the worktree given as a path or branch. Add --reason to say why.'
    option :reason, type: :string, desc: 'Why the worktree is locked'
    def lock(worktree = nil)
      run_command('worktree lock', Commands::WorktreeLock, *[worktree].compact)
    end

    desc 'unlock WORKTREE', 'Unlock a worktree'
    def unlock(worktree = nil)
      run_command('worktree unlock', Commands::WorktreeUnlock, *[worktree].compact)
    end

    desc 'move WORKTREE PATH', 'Move a worktree to another directory'
    long_desc <<~TEXT
      Moves the worktree (a path or branch) to PATH. The main checkout and the current worktree
      cannot be moved; a locked worktree needs --force.
    TEXT
    option :force, type: :boolean, default: false, desc: 'Also move a locked worktree'
    def move(worktree = nil, destination = nil)
      run_command('worktree move', Commands::WorktreeMove, *[worktree, destination].compact)
    end

    desc 'prune', 'Forget worktrees whose directory is gone'
    long_desc <<~TEXT
      Removes git's record of worktrees whose directory no longer exists. Locked worktrees stay.
      Branches are not touched. Asks for confirmation; pass --yes to skip it, or --dry-run.
    TEXT
    def prune
      run_command('worktree prune', Commands::WorktreePrune)
    end

    desc 'clean', 'Remove worktrees whose branch is merged, gone, stale or agent-created'
    long_desc <<~TEXT
      Removes worktrees whose branch matches the criteria of `gitflash clean`: merged into the
      default branch or upstream gone by default, plus --stale [DAYS] and --agent. The main
      checkout, the current worktree and worktrees on protected branches are never removed;
      locked worktrees and worktrees with uncommitted changes are skipped (and listed with the
      reason) unless --force is given.

      Each removal saves a snapshot first, as `wt remove` does. Branches are kept: run
      `gitflash clean` afterwards to delete them. Missing directories are handled by `wt prune`.

      Asks for confirmation; pass --yes to skip it, or --dry-run.
    TEXT
    option :merged, type: :boolean, desc: 'Branches merged into the default branch'
    option :gone, type: :boolean, desc: 'Branches whose upstream branch was deleted'
    option :stale, type: :string, banner: 'DAYS', lazy_default: '',
                   desc: 'Branches without commits for DAYS days (default: stale_days setting)'
    option :agent, type: :boolean, desc: 'Branches created by an agent'
    option :force, type: :boolean, default: false,
                   desc: 'Also remove locked worktrees and worktrees with uncommitted changes'
    def clean
      run_command('worktree clean', Commands::WorktreeClean)
    end

    desc 'remove [WORKTREE...]', 'Remove worktrees (paths or branch names), saving a snapshot first'
    long_desc descriptions.worktree_remove.long
    option :force, type: :boolean, default: false,
                   desc: 'Remove locked worktrees and worktrees with uncommitted changes'
    def remove(*worktrees)
      run_command('worktree remove', Commands::WorktreeRemove, *worktrees)
    end
  end
end
