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
end
