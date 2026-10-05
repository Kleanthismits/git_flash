# frozen_string_literal: true

RSpec.describe Gitflash::Restore, :git_repo do
  let(:snapshots) { Gitflash::Snapshots.new }

  before do
    commit_file('a', "1\n")
    commit_file('b', "2\n")
    git('branch', 'feature')
  end

  def restore(snapshot)
    described_class.new(snapshots.find(snapshot.id))
  end

  it 'restores files after reset --hard and clean -fd' do
    File.write('a', "edited\n")
    File.write('staged', "s\n")
    git('add', 'staged')
    File.write('untracked', "u\n")
    before = git('status', '--porcelain')
    snapshot = snapshots.create(reason: 'test')
    tip = head_sha
    git('reset', '-q', '--hard', 'HEAD~1')
    git('clean', '-qfd')

    result = restore(snapshot)
    expect(result.plan).to include(worktree: true, head: nil)
    expect(result.apply).to be_nil
    expect(head_sha).to eq(tip)
    expect(git('status', '--porcelain')).to eq(before)
    expect(File.read('a')).to eq("edited\n")
  end

  it 'recreates a deleted branch and moves a moved one back' do
    snapshot = snapshots.create(reason: 'test', scope: %w[branches])
    old = head_sha
    git('branch', '-D', 'feature')
    commit_file('c')

    result = restore(snapshot)
    expect(result.plan[:branches]).to contain_exactly(
      { branch: 'feature', from: nil, to: old }, { branch: 'main', from: head_sha, to: old }
    )
    result.apply
    expect(branch_names).to eq(%w[feature main])
    expect(git('rev-parse', 'feature').strip).to eq(old)
  end

  it 'does not overwrite a branch that was created after the restore was planned' do
    snapshot = snapshots.create(reason: 'test', scope: %w[branches])
    old = head_sha
    git('branch', '-D', 'feature')
    result = restore(snapshot)
    expect(result.plan[:branches]).to eq([{ branch: 'feature', from: nil, to: old }])

    commit_file('c')
    git('branch', 'feature') # another process creates it after planning
    expect(result.apply).not_to be_nil
    expect(git('rev-parse', 'feature').strip).to eq(head_sha)
  end

  it 'switches HEAD back with a checkout that keeps local changes' do
    snapshot = snapshots.create(reason: 'test', scope: %w[head])
    git('checkout', '-q', 'feature')
    File.write('local', "keep\n")

    result = restore(snapshot)
    expect(result.plan[:head]).to eq(from: 'feature', to: 'main')
    result.apply
    expect(git('branch', '--show-current')).to eq("main\n")
    expect(File.read('local')).to eq("keep\n")
  end

  it 'restores branches and HEAD by their real names when tags have the same names' do
    git('tag', 'main')
    git('tag', 'feature')
    snapshot = snapshots.create(reason: 'test', scope: %w[branches head])
    expect(snapshot).to have_attributes(head: include(branch: 'main'),
                                        branches: include('main', 'feature'))
    git('checkout', '-q', '-b', 'other')
    git('branch', '-q', '-D', 'feature')

    result = restore(snapshot)
    expect(result.plan[:head]).to eq(from: 'other', to: 'main')
    expect(result.plan[:branches].map { |change| change[:branch] }).to eq(%w[feature])
    expect(result.apply).to be_nil
    expect(git('branch', '--show-current')).to eq("main\n")
    refs = git('for-each-ref', '--format=%(refname)', 'refs/heads/').split
    expect(refs).to contain_exactly('refs/heads/feature', 'refs/heads/main', 'refs/heads/other')
  end

  it 'restores dropped stash entries' do
    File.write('a', "stashed\n")
    git('stash', '-q')
    stash = git('rev-parse', 'stash@{0}').strip
    snapshot = snapshots.create(reason: 'test', scope: %w[stashes])
    git('stash', 'drop', '-q')

    restore(snapshot).apply
    expect(git('rev-parse', 'stash@{0}').strip).to eq(stash)
  end

  it 'leaves files and branches created after the snapshot alone' do
    snapshot = snapshots.create(reason: 'test')
    git('branch', 'later')
    File.write('later.txt', "new\n")

    restore(snapshot).apply
    expect(branch_names).to include('later')
    expect(File.read('later.txt')).to eq("new\n")
  end

  it 'has an empty plan when nothing changed' do
    expect(restore(snapshots.create(reason: 'test'))).to be_empty
  end
end
