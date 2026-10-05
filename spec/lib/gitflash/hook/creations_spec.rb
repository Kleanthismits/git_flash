# frozen_string_literal: true

RSpec.describe Gitflash::Hook::Creations do
  def branch_of(command)
    subcommand, *args = command.split
    described_class.for(subcommand, args)
  end

  {
    'checkout -b feat' => 'feat',
    'checkout -B feat origin/main' => 'feat',
    'checkout -bfeat' => 'feat',
    'checkout -q -b feat' => 'feat',
    'switch -c feat' => 'feat',
    'switch -C feat main' => 'feat',
    'switch --create feat' => 'feat',
    'switch --create=feat' => 'feat',
    'branch feat' => 'feat',
    'branch feat main' => 'feat',
    'branch --track feat origin/feat' => 'feat',
    'worktree add -b feat ../wt' => 'feat',
    'worktree add ../wt/topic' => 'topic',
    'worktree add --lock ../wt/topic' => 'topic'
  }.each do |command, branch|
    it "finds #{branch} in `git #{command}`" do
      expect(branch_of(command)).to eq(branch)
    end
  end

  [
    'checkout main', 'checkout -- .', 'checkout -b', 'switch main', 'switch -', 'status',
    'branch', 'branch -d feat', 'branch -D feat', 'branch -m old new', 'branch --list',
    'branch -a', 'branch -vv', 'branch --show-current', 'branch --set-upstream-to=origin/x',
    'branch -c old new', 'worktree add --detach ../wt', 'worktree add ../wt main',
    'worktree add --orphan ../wt', 'worktree remove ../wt', 'worktree list', 'reset --hard'
  ].each do |command|
    it "finds nothing in `git #{command}`" do
      expect(branch_of(command)).to be_nil
    end
  end

  it 'does not take the value of --reason for the path of a worktree' do
    expect(branch_of('worktree add --reason busy ../wt/topic')).to eq('topic')
  end
end
