# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Cli, :git_repo do
  let(:outside) { Dir.mktmpdir('gitflash-wt') }

  before do
    commit_file('a.txt')
    allow(Dir).to receive(:home).and_return(outside) # not the developer's own settings
  end

  after { FileUtils.remove_entry(outside) }

  def wt_path(name) = File.join(File.realpath(outside), name)

  def result_of(run) = run.json['result']

  def owner_of(branch)
    git('config', '--local', '--get', "branch.#{branch}.gitflash-owner").strip
  rescue RuntimeError
    nil
  end

  describe 'worktree add' do
    it 'creates a new branch in a new directory and marks it as agent work' do
      run = run_cli('wt', 'add', 'feat/x', '--path', wt_path('x'), '--json')
      expect(run.status).to eq(0)
      expect(result_of(run)).to include('branch' => 'feat/x', 'path' => wt_path('x'),
                                        'source' => 'new', 'owner' => 'agent', 'head' => head_sha)
      expect(git('-C', wt_path('x'), 'branch', '--show-current').strip).to eq('feat/x')
      expect(owner_of('feat/x')).to eq('agent')
    end

    it 'puts the worktree where worktree_dir in .gitflash.yml says' do
      File.write('.gitflash.yml', "worktree_dir: #{outside}/%<repo>s-%<branch>s\n")
      path = result_of(run_cli('wt', 'add', 'topic', '--json'))['path']
      expect(path).to eq(File.join(outside, "#{File.basename(Dir.pwd)}-topic"))
      expect(File.directory?(path)).to be(true)
    end

    it 'starts a new branch from --from and marks it human when asked' do
      first = head_sha
      commit_file('b.txt')
      run = run_cli('wt', 'add', 'old', '--path', wt_path('old'), '--from', first,
                    '--owner', 'human', '--json')
      expect(result_of(run)).to include('head' => first, 'owner' => 'human')
    end

    it 'checks out an existing branch without changing its mark' do
      git('branch', 'existing')
      run = run_cli('wt', 'add', 'existing', '--path', wt_path('e'), '--json')
      expect(result_of(run)).to include('source' => 'existing', 'owner' => nil)
      expect(owner_of('existing')).to be_nil
    end

    it 'tracks a branch that exists only on origin' do
      remote = File.join(outside, 'remote.git')
      git('init', '-q', '--bare', remote)
      git('remote', 'add', 'origin', remote)
      git('branch', 'shared')
      git('push', '-q', 'origin', 'shared')
      git('branch', '-D', 'shared')
      git('fetch', '-q', 'origin')

      run = run_cli('wt', 'add', 'shared', '--path', wt_path('s'), '--json')
      expect(result_of(run)).to include('source' => 'remote', 'owner' => 'agent')
      expect(git('rev-parse', '--abbrev-ref', 'shared@{upstream}').strip).to eq('origin/shared')
    end

    it 'refuses a branch that is already checked out in a worktree' do
      run = run_cli('wt', 'add', 'main', '--path', wt_path('m'), '--json')
      expect(run.status).to eq(2)
      expect(run.json['error']).to include('code' => 'invalid_usage')
      expect(run.json['error']['message']).to include('already checked out at')
    end

    it 'refuses --from for an existing branch, a bad name and a used directory' do
      git('branch', 'existing')
      expect(run_cli('wt', 'add', 'existing', '--from', 'main', '--json').json['error'])
        .to include('code' => 'invalid_options')
      expect(run_cli('wt', 'add', '-x',
                     '--json').json['error']).to include('code' => 'invalid_usage')
      expect(run_cli('wt', 'add', 'bad..name', '--json').json['error'])
        .to include('code' => 'invalid_usage')
      expect(run_cli('wt', 'add', '--json').json['error']).to include('code' => 'invalid_usage')
      FileUtils.mkdir_p(wt_path('used'))
      File.write(File.join(wt_path('used'), 'f'), 'x')
      expect(run_cli('wt', 'add', 'n', '--path', wt_path('used'),
                     '--json').json['error']['message'])
        .to include('not an empty directory')
    end

    it 'changes nothing with --dry-run' do
      run = run_cli('wt', 'add', 'dry', '--path', wt_path('dry'), '--dry-run', '--json')
      expect(run.json).to include('status' => 'planned')
      expect(File.exist?(wt_path('dry'))).to be(false)
      expect(branch_names).not_to include('dry')
    end
  end

  describe 'worktree remove' do
    before { run_cli('wt', 'add', 'feat', '--path', wt_path('feat')) }

    def remove(*args) = run_cli('wt', 'remove', *args, '--json')

    it 'asks for confirmation without --yes' do
      run = remove('feat')
      expect(run).to have_attributes(status: 2)
      expect(run.json['status']).to eq('confirmation_required')
      expect(File.directory?(wt_path('feat'))).to be(true)
    end

    it 'refuses the main checkout, the current worktree and unknown worktrees' do
      expect(remove(Dir.pwd, '--yes').json['error']).to include('code' => 'protected_worktree')
      Dir.chdir(wt_path('feat')) do
        expect(remove('feat', '--yes').json['error']['message']).to include('current worktree')
      end
      expect(remove('nope', '--yes').json['error']).to include('code' => 'unknown_worktree')
    end

    it 'refuses dirty and locked worktrees unless --force' do
      File.write(File.join(wt_path('feat'), 'wip.txt'), 'x')
      expect(remove('feat', '--yes').json['error']['message']).to include('uncommitted changes')
      File.delete(File.join(wt_path('feat'), 'wip.txt'))
      git('worktree', 'lock', wt_path('feat'))
      expect(remove('feat', '--yes').json['error']['message']).to include('locked')
      expect(remove('feat', '--yes', '--force').status).to eq(0)
      expect(File.exist?(wt_path('feat'))).to be(false)
    end

    it 'removes a clean worktree by branch or path and undo brings it back' do
      run = remove('feat', '--yes')
      expect(run.status).to eq(0)
      row = result_of(run)['removed'].first
      expect(row).to include('path' => wt_path('feat'), 'branch' => 'feat')
      expect(run.json['undo']).to include('snapshot' => row['snapshot'])
      expect(File.exist?(wt_path('feat'))).to be(false)
      expect(branch_names).to include('feat')

      undo = run_cli('undo', row['snapshot'], '--yes', '--json')
      expect(undo.status).to eq(0)
      expect(undo.json['plan']).to include('recreate_worktree' => wt_path('feat'))
      expect(git('-C', wt_path('feat'), 'branch', '--show-current').strip).to eq('feat')
    end

    it 'saves uncommitted and untracked files, and undo restores them in the new directory' do
      File.write(File.join(wt_path('feat'), 'a.txt'), 'changed')
      File.write(File.join(wt_path('feat'), 'new.txt'), 'untracked')
      run = remove(wt_path('feat'), '--yes', '--force')
      snapshot = result_of(run)['removed'].first['snapshot']

      run_cli('undo', snapshot, '--yes')
      expect(File.read(File.join(wt_path('feat'), 'a.txt'))).to eq('changed')
      expect(File.read(File.join(wt_path('feat'), 'new.txt'))).to eq('untracked')
    end

    it 'brings back a worktree on a detached HEAD' do
      git('worktree', 'add', '-q', '--detach', wt_path('det'))
      run = remove(wt_path('det'), '--yes')
      id = result_of(run)['removed'].first['snapshot']
      run_cli('undo', id, '--yes')
      expect(git('-C', wt_path('det'), 'rev-parse', 'HEAD').strip).to eq(head_sha)
    end

    it 'recreates the branch too when it was deleted after the removal' do
      id = result_of(remove('feat', '--yes'))['removed'].first['snapshot']
      git('branch', '-D', 'feat')
      expect(run_cli('undo', id, '--yes').status).to eq(0)
      expect(git('-C', wt_path('feat'), 'branch', '--show-current').strip).to eq('feat')
    end

    it 'removes a worktree whose directory is already gone' do
      FileUtils.rm_rf(wt_path('feat'))
      run = remove('feat', '--yes')
      expect(run.status).to eq(0)
      expect(git('worktree', 'list').lines.size).to eq(1)
    end

    it 'prints a plan with --dry-run and changes nothing' do
      run = remove('feat', '--dry-run')
      expect(run.json['status']).to eq('planned')
      expect(File.directory?(wt_path('feat'))).to be(true)
    end
  end
end
