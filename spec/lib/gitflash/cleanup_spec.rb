# frozen_string_literal: true

RSpec.describe Gitflash::Cleanup do
  let(:now) { Time.utc(2026, 10, 5) }
  let(:config) { Gitflash::Config.defaults }
  let(:protection) { Gitflash::Protection.new(config: config) }

  def branch(name, **fields)
    Gitflash::Branch.new(
      name: name, sha: 'a' * 40, current: false, default: false, upstream: nil,
      upstream_gone: false, ahead: 0, behind: 0, merged: false,
      last_commit_at: now - (86_400 * 5), last_commit_author: 'x', last_commit_subject: 's',
      **fields
    )
  end

  def rules(*criteria, stale_days: 30)
    described_class::Rules.new(criteria: criteria, stale_days: stale_days, now: now)
  end

  def names(candidates) = candidates.map { |candidate| candidate.item.name }

  describe '.branches' do
    let(:all) do
      [branch('main', default: true, merged: true), branch('cur', current: true, merged: true),
       branch('done', merged: true), branch('gone', upstream_gone: true),
       branch('old', last_commit_at: now - (86_400 * 90)), branch('bot', owner: 'agent'),
       branch('plain'), branch('release/1', merged: true)]
    end

    it 'selects merged and gone by default, with reasons, and never protected branches' do
      config_with = Gitflash::Config.new(protected_patterns: ['release/*'], stale_days: 30,
                                         worktree_dir: 'x')
      guard = Gitflash::Protection.new(config: config_with)
      result = described_class.branches(all, rules: rules(*described_class::DEFAULT_CRITERIA),
                                             protection: guard)
      expect(result.to_h { |c| [c.item.name, c.reasons] })
        .to eq('done' => ['merged'], 'gone' => ['upstream gone'])
    end

    it 'adds stale and agent-created branches when asked' do
      result = described_class.branches(all, rules: rules(:stale, :agent), protection: protection)
      expect(result.to_h { |c| [c.item.name, c.reasons] })
        .to eq('old' => ['no commits for 30 days'], 'bot' => ['agent-created'])
    end

    it 'lists every reason a branch matches' do
      both = branch('both', merged: true, owner: 'agent')
      result = described_class.branches([both], rules: rules(:merged, :agent),
                                                protection: protection)
      expect(result.first.reasons).to eq(%w[merged agent-created])
    end

    it 'never selects a branch checked out in a worktree' do
      held = Gitflash::Protection.new(config: config, checked_out: ['done'])
      expect(names(described_class.branches(all, rules: rules(:merged), protection: held)))
        .not_to include('done')
    end

    it 'selects nothing without matches' do
      expect(described_class.branches([branch('plain')], rules: rules(:merged, :gone),
                                                         protection: protection)).to eq([])
    end
  end

  describe '.worktrees' do
    def worktree(path, branch, **fields)
      Gitflash::Worktree.new(path: path, head: 'a' * 40, branch: branch, main: false, bare: false,
                             locked: false, lock_reason: nil, missing: false, dirty: false,
                             ahead: 0, behind: 0, merged: nil, owner: nil, **fields)
    end

    let(:branches) do
      [branch('main', default: true), branch('done', merged: true), branch('dirty', merged: true),
       branch('lock', merged: true)]
    end
    let(:trees) do
      [worktree('/r', 'main', main: true), worktree('/w/done', 'done'),
       worktree('/w/dirty', 'dirty', dirty: true), worktree('/w/lock', 'lock', locked: true),
       worktree('/w/det', nil)]
    end

    def blocker = ->(worktree) { worktree.removal_blocker(force: false, current: false) }

    it 'chooses clean unlocked matches and reports why the others were skipped' do
      chosen, skipped = described_class.worktrees(trees, branches: branches, rules: rules(:merged),
                                                         protection: protection, blocker: blocker)
      expect(chosen.map { |c| c.item.path }).to eq(['/w/done'])
      expect(skipped.map { |row| [row[:path], row[:reason]] }).to eq(
        [['/w/dirty', '/w/dirty has uncommitted changes (use --force)'],
         ['/w/lock', '/w/lock is locked (use --force)']]
      )
    end
  end
end
