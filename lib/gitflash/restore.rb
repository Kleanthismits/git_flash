# frozen_string_literal: true

module Gitflash
  # Plans and applies the restore of a snapshot. Only the parts in the snapshot's scope are
  # restored, and only where the repository differs from the snapshot. Branches and files
  # created after the snapshot are left alone.
  class Restore
    def initialize(snapshot, bash: Git::BashCommand)
      @snapshot = snapshot
      @bash = bash
    end

    # { branches: [{branch, from, to}], head: {from, to} | nil, worktree: bool, stashes: [sha] }
    def plan
      @plan ||= {
        branches: @snapshot.scope?('branches') ? branch_changes : [],
        head: @snapshot.scope?('head') ? head_change : nil,
        worktree: @snapshot.scope?('worktree') && worktree_differs?,
        stashes: @snapshot.scope?('stashes') ? missing_stashes : []
      }
    end

    # Parts of the state this restore changes; the state before an undo is saved with the same
    def scope = @snapshot.scope

    def empty?
      plan[:branches].empty? && plan[:head].nil? && !plan[:worktree] && plan[:stashes].empty?
    end

    # Applies the plan; returns nil on success or the failed step's Result
    def apply
      steps.lazy.map { |args| run(*args) }.find { |result| !result.success? }
    end

    private

    def steps
      branch_steps + head_steps + worktree_steps + stash_steps
    end

    def branch_steps
      plan[:branches].map do |change|
        # An empty old value makes git refuse to overwrite a branch created since the plan
        ['update-ref', "refs/heads/#{change[:branch]}", change[:to], change[:from] || '']
      end
    end

    # With the worktree in scope HEAD is moved directly and the files are restored next;
    # otherwise a normal checkout keeps local changes.
    def head_steps
      return [] unless plan[:head]

      branch = @snapshot.head[:branch]
      sha = @snapshot.head[:sha]
      if @snapshot.scope?('worktree')
        detach = ['update-ref', '--no-deref', 'HEAD', sha]
        [branch ? ['symbolic-ref', 'HEAD', "refs/heads/#{branch}"] : detach]
      else
        [branch ? ['switch', '--', branch] : ['checkout', '--detach', sha]]
      end
    end

    # Working tree first (tracked and snapshot-untracked files), then the staged state
    def worktree_steps
      return [] unless plan[:worktree] && target_worktree

      steps = [['read-tree', '--reset', '-u', target_worktree]]
      steps << ['read-tree', '--reset', target_index] if target_index != target_worktree
      steps
    end

    def stash_steps
      plan[:stashes].reverse.map { |sha| ['stash', 'store', '-m', 'gitflash undo', sha] }
    end

    def target_worktree
      @snapshot.worktree || @snapshot.head[:sha]
    end

    def target_index
      return @snapshot.index if @snapshot.index

      @snapshot.worktree ? @snapshot.head[:sha] : target_worktree
    end

    def branch_changes
      tips = current_tips
      @snapshot.branches.filter_map do |name, sha|
        { branch: name, from: tips[name], to: sha } unless tips[name] == sha
      end
    end

    def head_change
      current = current_head
      target = @snapshot.head
      same = if target[:branch]
               current[:branch] == target[:branch]
             else
               current[:branch].nil? && current[:sha] == target[:sha]
             end
      same ? nil : { from: current[:branch] || current[:sha], to: target[:branch] || target[:sha] }
    end

    def current_head
      { branch: capture('symbolic-ref', '--quiet', 'HEAD')&.delete_prefix(Repo::HEADS),
        sha: capture('rev-parse', '--verify', '--quiet', 'HEAD^{commit}') }
    end

    def worktree_differs?
      return true unless capture('status', '--porcelain', '--untracked-files=all').to_s.empty?

      target_worktree && tree_of(target_worktree) != tree_of('HEAD')
    end

    def missing_stashes
      @snapshot.stashes - capture('stash', 'list', '--format=%H').to_s.split
    end

    def current_tips
      Branch.parse_tips(capture('for-each-ref', "--format=#{Branch::TIPS_FORMAT}", Repo::HEADS))
    end

    def tree_of(ref)
      capture('rev-parse', '--verify', '--quiet', "#{ref}^{tree}")
    end

    # Stripped stdout of a git command, or nil when it fails
    def capture(*)
      stdout, _stderr, success = @bash.capture('git', *)
      success ? stdout.strip : nil
    end

    def run(*)
      stdout, stderr, success = @bash.capture('git', *)
      output = [stdout, stderr].map(&:strip).reject(&:empty?).join("\n")
      Result.new(success: success, output: output)
    end
  end
end
