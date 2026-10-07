# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Cli, :git_repo do
  let(:outside) { Dir.mktmpdir('gitflash-wtclean') }

  before do
    commit_file('a.txt')
    allow(Dir).to receive(:home).and_return(outside) # not the developer's own settings
  end

  after { FileUtils.remove_entry(outside) }

  def wt_path(name) = File.join(File.realpath(outside), name)

  def add(branch, *args) = run_cli('wt', 'add', branch, '--path', wt_path(branch), *args)

  def wt_clean(*args) = run_cli('wt', 'clean', *args, '--json')

  def branches_of(rows) = rows.map { |row| row['branch'] }

  # Gives the worktree a commit main does not have
  def diverge(branch)
    Dir.chdir(wt_path(branch)) { commit_file("#{branch}.txt") }
  end

  it 'selects worktrees on merged branches and keeps the rest' do
    add('done')
    add('busy')
    diverge('busy')
    run = wt_clean('--dry-run')
    expect(run.json['status']).to eq('planned')
    expect(run.json['plan']['worktrees'].map { |row| [row['branch'], row['reasons']] })
      .to eq([['done', ['merged']]])
  end

  it 'removes them after confirmation, snapshots, and undo brings one back' do
    add('done')
    expect(wt_clean).to have_attributes(status: 2)

    run = wt_clean('--yes')
    expect(run.status).to eq(0)
    row = run.json['result']['removed'].first
    expect(File.exist?(wt_path('done'))).to be(false)
    expect(branch_names).to include('done')

    run_cli('undo', row['snapshot'], '--yes')
    expect(File.directory?(wt_path('done'))).to be(true)
  end

  it 'skips dirty and locked worktrees with the reason, unless --force' do
    add('dirty')
    add('locked')
    File.write(File.join(wt_path('dirty'), 'wip.txt'), 'x')
    git('worktree', 'lock', wt_path('locked'))

    run = wt_clean('--dry-run')
    expect(run.json['status']).to eq('noop')
    expect(branches_of(run.json['plan']['skipped'])).to contain_exactly('dirty', 'locked')

    forced = wt_clean('--dry-run', '--force')
    expect(branches_of(forced.json['plan']['worktrees'])).to contain_exactly('dirty', 'locked')
  end

  it 'selects agent-created worktrees with --agent and respects protected branches' do
    add('bot')
    diverge('bot')
    add('human', '--owner', 'human')
    diverge('human')
    File.write('.gitflash.yml', "protected: ['bot']\n")
    expect(wt_clean('--agent', '--dry-run').json['status']).to eq('noop')

    File.write('.gitflash.yml', "stale_days: 30\n")
    rows = wt_clean('--agent', '--dry-run').json['plan']['worktrees']
    expect(rows.to_h { |row| [row['branch'], row['reasons']] }).to eq('bot' => ['agent-created'])
  end

  it 'never touches the main checkout or the current worktree' do
    add('done')
    Dir.chdir(wt_path('done')) do
      run = wt_clean('--yes')
      expect(run.json['status']).to eq('noop')
      expect(run.json['plan']['worktrees']).to eq([])
    end
    expect(File.directory?(wt_path('done'))).to be(true)
  end

  it 'reports nothing to clean' do
    expect(run_cli('wt', 'clean').stdout).to eq("Nothing to clean\n")
  end
end
