# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Hook::BranchMarker, :git_repo do
  subject(:marker) { described_class.new(clock: -> { now }) }

  let(:now) { Time.now }

  before { commit_file('a.txt') }

  def owners = Gitflash::Ownership.new.all

  def mark(command, cwd = Dir.pwd) = marker.call(command, cwd)

  it 'marks a branch the command just created' do
    git('checkout', '-q', '-b', 'feat')
    expect(mark('git checkout -b feat')).to eq(['feat'])
    expect(owners).to eq('feat' => 'agent')
  end

  it 'marks every branch of a chain, once each' do
    git('switch', '-q', '-c', 'a')
    git('branch', 'b')
    expect(mark('git switch -c a && git branch b && git branch b')).to eq(%w[a b])
    expect(owners).to eq('a' => 'agent', 'b' => 'agent')
  end

  it 'marks a branch created with worktree add in the directory given by -C' do
    Dir.mktmpdir do |dir|
      git('worktree', 'add', '-q', '-b', 'wt', File.join(dir, 'wt'))
      expect(mark("git -C #{Dir.pwd} worktree add -b wt #{dir}/wt", '/')).to eq(['wt'])
    end
    expect(owners).to eq('wt' => 'agent')
  end

  it 'does not claim a branch that was already there' do
    git('branch', 'old')
    later = Time.now + 3600
    expect(described_class.new(clock: -> { later }).call('git checkout -b old', Dir.pwd)).to eq([])
    expect(owners).to eq({})
  end

  it 'keeps an existing mark, including a human one' do
    git('branch', 'mine')
    Gitflash::Ownership.new.mark('mine', 'human')
    expect(mark('git branch mine')).to eq([])
    expect(owners).to eq('mine' => 'human')
  end

  it 'marks nothing when the branch does not exist or the command creates none' do
    expect(mark('git checkout -b ghost')).to eq([])
    git('branch', 'other')
    expect(mark('git checkout other && git branch -d other')).to eq([])
    expect(owners).to eq({})
  end

  it 'ignores a directory that is not a git work tree' do
    Dir.mktmpdir do |dir|
      expect(mark('git branch x', dir)).to eq([])
    end
  end

  describe 'with the branches recorded before the command' do
    subject(:marker) { described_class.new(clock: -> { now }, state_dir: state) }

    let(:state) { Dir.mktmpdir('gitflash-state') }

    after { FileUtils.remove_entry(state) }

    it 'never claims a branch that existed before the command, even a minutes-old human one' do
      git('branch', 'mine')
      marker.record('git branch mine', Dir.pwd, 'toolu_1')
      expect(marker.call('git branch mine', Dir.pwd, 'toolu_1')).to eq([])
      expect(owners).to eq({})
    end

    it 'marks a branch that the command created' do
      marker.record('git checkout -b feat', Dir.pwd, 'toolu_2')
      git('checkout', '-q', '-b', 'feat')
      expect(marker.call('git checkout -b feat', Dir.pwd, 'toolu_2')).to eq(['feat'])
    end

    it 'marks a branch that the command deleted and created again' do
      git('branch', 'topic')
      command = 'git branch -D topic && git switch -c topic'
      marker.record(command, Dir.pwd, 'toolu_re')

      git('branch', '-D', 'topic')
      git('switch', '-q', '-c', 'topic')
      expect(marker.call(command, Dir.pwd, 'toolu_re')).to eq(['topic'])
      expect(owners).to eq('topic' => 'agent')
    end

    it 'still ignores a branch that was only left alone by the command' do
      git('branch', 'topic')
      marker.record('git switch -c topic', Dir.pwd, 'toolu_same')
      expect(marker.call('git switch -c topic', Dir.pwd, 'toolu_same')).to eq([])
    end

    it 'marks only the new branch of a chain when another one existed' do
      git('branch', 'old')
      marker.record('git branch old && git branch fresh', Dir.pwd, 'toolu_3')
      git('branch', 'fresh')
      expect(marker.call('git branch old && git branch fresh', Dir.pwd, 'toolu_3')).to eq(['fresh'])
    end

    it 'does not mark a branch whose creation was skipped by the shell' do
      git('branch', 'human')
      command = 'false && git branch human'
      marker.record(command, Dir.pwd, 'toolu_4')
      expect(marker.call(command, Dir.pwd, 'toolu_4')).to eq([])
    end

    it 'writes nothing into a state directory that is open to others' do
      FileUtils.chmod(0o777, state)
      marker.record('git branch x', Dir.pwd, 'toolu_open')
      expect(Dir.children(state)).to be_empty
    end

    it 'writes nothing through a state directory that is a symbolic link' do
      real = Dir.mktmpdir('gitflash-real')
      link = File.join(Dir.mktmpdir('gitflash-link'), 'state')
      File.symlink(real, link)
      linked = described_class.new(clock: -> { now }, state_dir: link)

      linked.record('git branch x', Dir.pwd, 'toolu_link')
      expect(Dir.children(real)).to be_empty
    end

    it 'keeps pruning when another hook removes a record at the same moment' do
      marker.record('git branch x', Dir.pwd, 'toolu_a')
      allow(File).to receive(:mtime).and_raise(Errno::ENOENT)
      expect { marker.record('git branch y', Dir.pwd, 'toolu_b') }.not_to raise_error
    end

    it 'deletes the record after use and keeps ids from forming paths' do
      marker.record('git branch x', Dir.pwd, '../../etc/passwd')
      expect(Dir.children(state).size).to eq(1)
      expect(Dir.children(state).first).to match(/\A\h{64}\.json\z/)
      marker.call('git branch x', Dir.pwd, '../../etc/passwd')
      expect(Dir.children(state)).to be_empty
    end

    it 'removes records that were never used after a day' do
      marker.record('git branch x', Dir.pwd, 'toolu_old')
      old = File.join(state, Dir.children(state).first)
      File.utime(now - (2 * 86_400), now - (2 * 86_400), old)
      marker.record('git branch y', Dir.pwd, 'toolu_new')
      expect(Dir.children(state).size).to eq(1)
    end
  end
end
