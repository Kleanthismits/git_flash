# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  before do
    commit_file('a.txt')
    git('branch', 'one')
    git('branch', 'two')
  end

  def mark(*args) = run_cli('mark', *args, '--json')

  def rows(run) = run.json['result']['branches']

  def owners = Gitflash::Ownership.new.all

  it 'marks the current branch as agent work by default' do
    run = mark
    expect(run.status).to eq(0)
    expect(run.json['plan']).to eq('branches' => ['main'], 'owner' => 'agent')
    expect(rows(run)).to eq([{ 'branch' => 'main', 'owner' => 'agent', 'previous' => nil }])
    expect(owners).to eq('main' => 'agent')
  end

  it 'marks the given branches and reports each previous mark' do
    Gitflash::Ownership.new.mark('two', 'human')
    run = mark('one', 'two', '--owner', 'agent')
    expect(rows(run)).to eq([{ 'branch' => 'one', 'owner' => 'agent', 'previous' => nil },
                             { 'branch' => 'two', 'owner' => 'agent', 'previous' => 'human' }])
    expect(owners).to eq('one' => 'agent', 'two' => 'agent')
  end

  it 'sets human and clears a mark, and says when nothing changes' do
    mark('one')
    expect(mark('one', '--owner', 'human').json['status']).to eq('done')
    expect(owners).to eq('one' => 'human')

    cleared = mark('one', '--clear')
    expect(rows(cleared)).to eq([{ 'branch' => 'one', 'owner' => nil, 'previous' => 'human' }])
    expect(owners).to eq({})
    expect(mark('one', '--clear').json['status']).to eq('noop')
    expect(run_cli('mark', 'one', '--clear').stdout).to eq("one is already unmarked\n")
  end

  it 'prints readable text' do
    expect(run_cli('mark', 'one').stdout).to eq("Marked one as agent\n")
    expect(run_cli('mark', 'one').stdout).to eq("one is already agent\n")
    expect(run_cli('mark', 'one', '--clear').stdout).to eq("Cleared the mark of one (was agent)\n")
  end

  it 'changes nothing with --dry-run' do
    run = mark('one', '--dry-run')
    expect(run.json['status']).to eq('planned')
    expect(owners).to eq({})
  end

  it 'refuses unknown branches, bad owners, conflicting options and a detached HEAD' do
    expect(mark('nope').json['error']).to include('code' => 'unknown_branch')
    expect(mark('one', 'nope').json['error']['message']).to include('nope')
    expect(owners).to eq({})
    bad = run_cli('mark', 'one', '--owner', 'robot')
    expect(bad.stderr).to include('--owner', 'agent, human') # Thor checks the enum
    expect(mark('one', '--owner', 'agent', '--clear').json['error'])
      .to include('code' => 'invalid_options')
    git('checkout', '-q', '--detach')
    expect(mark.json['error']).to include('code' => 'invalid_usage')
  end

  it 'makes clean --agent select a marked branch' do
    git('switch', '-q', '-c', 'bot')
    commit_file('bot.txt')
    git('switch', '-q', 'main')
    mark('bot')
    run = run_cli('clean', '--agent', '--force', '--dry-run', '--json')
    expect(run.json['plan']['reasons']).to eq('bot' => ['agent-created'])
  end
end
