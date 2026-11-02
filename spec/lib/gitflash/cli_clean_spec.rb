# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Cli, :git_repo do
  let(:outside) { Dir.mktmpdir('gitflash-clean') }

  before do
    commit_file('a.txt')
    allow(Dir).to receive(:home).and_return(outside) # not the developer's own settings
  end

  after { FileUtils.remove_entry(outside) }

  def clean(*args) = run_cli('clean', *args, '--json')

  def plan_of(run) = run.json['plan']

  # A branch with a commit main does not have; `date` backdates that commit
  def unmerged_branch(name, date: nil)
    git('switch', '-q', '-c', name)
    ENV['GIT_COMMITTER_DATE'] = date
    commit_file("#{name.tr('/', '_')}.txt")
  ensure
    ENV.delete('GIT_COMMITTER_DATE')
    git('switch', '-q', 'main')
  end

  def mark(branch, owner) = Gitflash::Ownership.new.mark(branch, owner)

  it 'selects merged branches with their reasons and asks for confirmation' do
    merged_branch('done')
    unmerged_branch('wip')
    run = clean
    expect(run).to have_attributes(status: 2)
    expect(plan_of(run)).to include('branches' => ['done'], 'reasons' => { 'done' => ['merged'] })
  end

  it 'deletes with a snapshot, and undo brings the branches back' do
    merged_branch('done')
    sha = head_sha
    run = clean('--yes')
    expect(run.status).to eq(0)
    expect(run.json['result']['deleted']).to eq([{ 'branch' => 'done', 'sha' => sha[0, 7] }])
    expect(branch_names).not_to include('done')
    run_cli('undo', run.json['undo']['snapshot'], '--yes')
    expect(branch_names).to include('done')
  end

  it 'selects branches whose upstream is gone' do
    remote = File.join(outside, 'remote.git')
    git('init', '-q', '--bare', remote)
    git('remote', 'add', 'origin', remote)
    unmerged_branch('topic')
    git('push', '-q', '-u', 'origin', 'topic')
    git('push', '-q', 'origin', '--delete', 'topic')
    git('fetch', '-q', '--prune')

    run = clean('--yes', '--force')
    expect(plan_of(run)['reasons']).to eq('topic' => ['upstream gone'])
    expect(branch_names).not_to include('topic')
  end

  it 'keeps unmerged branches unless --force, and says why' do
    unmerged_branch('bot')
    mark('bot', 'agent')
    run = clean('--agent', '--dry-run')
    expect(run.json['status']).to eq('noop')
    expect(plan_of(run)['skipped']).to eq([{ 'branch' => 'bot',
                                             'reason' => 'has unmerged changes (use --force)' }])
    expect(branch_names).to include('bot')

    forced = clean('--agent', '--force', '--yes')
    expect(plan_of(forced)['reasons']).to eq('bot' => ['agent-created'])
    expect(branch_names).not_to include('bot')
  end

  it 'leaves unmarked branches alone for --agent' do
    git('branch', 'plain')
    expect(clean('--agent', '--yes').json['status']).to eq('noop')
    expect(branch_names).to include('plain')
  end

  it 'selects stale branches by days, from the flag or the stale_days setting' do
    unmerged_branch('old', date: '2020-01-01T00:00:00Z')
    unmerged_branch('fresh')
    expect(plan_of(clean('--stale', '30', '--force', '--dry-run'))['reasons'])
      .to eq('old' => ['no commits for 30 days'])

    File.write('.gitflash.yml', "stale_days: 3000\n")
    expect(clean('--stale', '--force', '--dry-run').json['status']).to eq('noop')
    File.write('.gitflash.yml', "stale_days: 10\n")
    expect(plan_of(clean('--stale', '--force', '--dry-run'))['reasons'].keys).to eq(['old'])
    expect(clean('--stale', 'soon').json['error']).to include('code' => 'invalid_options')
  end

  it 'never selects protected branches or branches checked out in a worktree' do
    git('branch', 'release/1')
    git('branch', 'held')
    git('worktree', 'add', '-q', File.join(outside, 'held'), 'held')
    File.write('.gitflash.yml', "protected: ['release/*']\n")
    merged_branch('done')
    expect(plan_of(clean('--dry-run'))['branches']).to eq(['done'])
  end

  it 'never selects the usual long-lived branches, even merged ones' do
    %w[develop development trunk release/2.0 done].each { |name| merged_branch(name) }
    expect(plan_of(clean('--dry-run'))['branches']).to eq(['done'])
  end

  describe 'without origin/HEAD' do
    before do
      merged_branch('done')
      git('remote', 'add', 'origin', File.join(outside, 'remote.git'))
    end

    it 'warns that the default branch was guessed, in the plan and the prompt text' do
      run = clean
      expect(plan_of(run)['warning']).to include('origin/HEAD is not set', 'main',
                                                 'git remote set-head origin --auto')
      expect(run.json.dig('error', 'message')).to include('Note: origin/HEAD is not set')
    end

    it 'warns in the plan of a clean with nothing to delete too' do
      git('branch', '-D', 'done')
      expect(plan_of(clean)['warning']).to include('origin/HEAD is not set')
    end

    it 'does not warn when the only remote is not origin' do
      git('remote', 'rename', 'origin', 'upstream')
      expect(plan_of(clean)).not_to have_key('warning')
    end

    it 'does not warn when origin/HEAD is set or there is no remote' do
      git('update-ref', 'refs/remotes/origin/main', 'HEAD')
      git('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main')
      expect(plan_of(clean)).not_to have_key('warning')
      git('remote', 'remove', 'origin')
      expect(plan_of(clean)).not_to have_key('warning')
    end
  end

  it 'combines criteria and lists every reason' do
    unmerged_branch('both', date: '2020-01-01T00:00:00Z')
    mark('both', 'agent')
    reasons = plan_of(clean('--agent', '--stale', '30', '--force', '--dry-run'))['reasons']
    expect(reasons['both']).to eq(['no commits for 30 days', 'agent-created'])
  end

  it 'keeps a branch nobody has committed to yet, and says why' do
    git('branch', 'fresh')
    mark('fresh', 'agent')
    %w[--merged --agent].each do |criterion|
      run = clean(criterion, '--force', '--dry-run')
      expect(run.json['status']).to eq('noop')
      expect(plan_of(run)['skipped'])
        .to eq([{ 'branch' => 'fresh', 'reason' => 'no commits since it was created; --stale ' \
                                                   'removes it after 30 days unused' }])
    end
  end

  it 'removes an unused branch with --stale once it has been unused that long' do
    ENV['GIT_COMMITTER_DATE'] = '2020-01-01T00:00:00Z' # commits and reflog entries take it
    commit_file('old.txt')
    git('branch', 'forgotten')
    ENV.delete('GIT_COMMITTER_DATE')
    commit_file('new.txt')
    git('branch', 'fresh')
    run = clean('--stale', '30', '--yes')
    expect(plan_of(run)['reasons']).to eq('forgotten' => ['no commits for 30 days'])
    expect(branch_names).to contain_exactly('main', 'fresh')
  ensure
    ENV.delete('GIT_COMMITTER_DATE')
  end

  it 'treats a branch cut now from an old commit as active, not stale' do
    unmerged_branch('old', date: '2020-01-01T00:00:00Z')
    git('branch', 'cut', 'old')
    expect(plan_of(clean('--stale', '30', '--force', '--dry-run'))['reasons'].keys).to eq(['old'])
  end

  it 'reports nothing to clean' do
    run = clean
    expect(run.json).to include('status' => 'noop')
    expect(run_cli('clean').stdout).to eq("Nothing to clean\n")
  end

  it 'makes delete refuse a branch checked out in a worktree' do
    git('branch', 'held')
    git('worktree', 'add', '-q', File.join(outside, 'held'), 'held')
    run = run_cli('delete', 'held', '--yes', '--json')
    expect(run.json['error']).to include('code' => 'protected_branch')
  end
end
