# frozen_string_literal: true

RSpec.describe Gitflash::Ownership, :git_repo do
  subject(:ownership) { described_class.new }

  before { commit_file('a.txt') }

  it 'has no marks in a fresh repository' do
    expect(ownership.all).to eq({})
  end

  it 'marks branches, including names with dots and slashes' do
    ownership.mark('feat/v1.2.x', 'agent')
    ownership.mark('main', 'human')
    expect(ownership.all).to eq('feat/v1.2.x' => 'agent', 'main' => 'human')
  end

  it 'replaces and clears a mark' do
    ownership.mark('main', 'agent')
    ownership.mark('main', 'human')
    expect(ownership.all).to eq('main' => 'human')
    ownership.clear('main')
    ownership.clear('main')
    expect(ownership.all).to eq({})
  end

  it 'rejects an unknown owner' do
    expect { ownership.mark('main', 'robot') }
      .to raise_error(Gitflash::UsageError, /Unknown owner 'robot'/)
  end

  it 'is removed by git together with the branch' do
    git('branch', 'temp')
    ownership.mark('temp', 'agent')
    git('branch', '-D', 'temp')
    expect(ownership.all).to eq({})
  end

  it 'shows up as owner on branches and worktrees' do
    git('branch', 'bot')
    ownership.mark('bot', 'agent')
    owners = Gitflash::Repo.new.branches.to_h { |branch| [branch.name, branch.owner] }
    expect(owners).to eq('main' => nil, 'bot' => 'agent')
    expect(run_cli('branches', '--json').json['result']['branches'].map { |b| b['owner'] })
      .to contain_exactly(nil, 'agent')
    expect(run_cli('wt', 'list', '--json').json['result']['worktrees'].first['owner']).to be_nil
  end
end
