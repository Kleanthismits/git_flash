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

    private

    def records
      @bash.exec('git', 'worktree', 'list', '--porcelain').split(/\n{2,}/)
           .reject { |block| block.strip.empty? }.map { |block| parse(block) }
    end

    def parse(block)
      block.each_line(chomp: true).to_h do |line|
        key, value = line.split(' ', 2)
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
      { ahead: info&.ahead, behind: info&.behind, merged: info&.merged }
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
