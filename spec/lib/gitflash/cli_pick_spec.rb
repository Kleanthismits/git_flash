# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  let(:shas) { {} }

  before do
    commit_file('a.txt', "base\n")
    git('switch', '-q', '-c', 'feat')
    %w[one two three].each { |name| shas[name] = commit_and_sha("#{name}.txt") }
    git('switch', '-q', 'main')
    commit_file('main.txt') # a different parent, so cherry-picks never reproduce the same SHA
  end

  def commit_and_sha(name)
    commit_file(name, "#{name}\n", message: "Add #{name.delete_suffix('.txt')}")
    head_sha
  end

  def pick(*args) = run_cli('pick', *args, '--json')

  def commits_of(run) = run.json['result']['commits']

  def subjects = git('log', '--format=%s', 'main').lines(chomp: true)

  # A branch whose commit changes a.txt, and main changing it differently
  def conflicting_branch(name = 'conf', extra: nil)
    git('switch', '-q', '-c', name, 'main')
    commit_file('a.txt', "#{name}\n", message: "Change a on #{name}")
    conflicting = head_sha
    extra && (extra_sha = commit_and_sha(extra))
    git('switch', '-q', 'main')
    commit_file('a.txt', "main\n", message: 'Change a on main')
    [conflicting, extra_sha]
  end

  describe '--list' do
    it 'lists the commits missing from the current branch, oldest first, with a diff summary' do
      run = pick('feat', '--list')
      expect(run.status).to eq(0)
      rows = commits_of(run)
      expect(rows.map { |row| row['subject'] }).to eq(['Add one', 'Add two', 'Add three'])
      expect(rows.first).to include('sha' => shas['one'], 'status' => 'new', 'author' => 'Spec',
                                    'files' => 1, 'insertions' => 1, 'deletions' => 0)
      expect(run.json['result']['source']).to eq('feat')
    end

    it 'marks commits whose change is already on the branch and never offers them' do
      git('cherry-pick', shas['two'])
      expect(commits_of(pick('feat', '--list')).to_h { |row| [row['subject'], row['status']] })
        .to eq('Add one' => 'new', 'Add two' => 'applied', 'Add three' => 'new')
      expect(run_cli('pick', 'feat', '--list').stdout).to match(/^= \h{7}  Add two/)
    end

    it 'prints a table, and says when there is nothing to pick' do
      expect(run_cli('pick', 'feat', '--list').stdout).to match(/^  \h{7}  Add one  \(Spec, /)
      git('switch', '-q', 'feat')
      git('branch', 'same')
      expect(run_cli('pick', 'same', '--list').stdout).to eq("No commits to pick.\n")
    end
  end

  describe 'picking' do
    it 'asks for confirmation and shows the plan' do
      run = pick('feat', shas['one'])
      expect(run.status).to eq(2)
      expect(run.json['plan']).to include('source' => 'feat', 'commits' => [shas['one']],
                                          'skipped' => [], 'commit' => true)
    end

    it 'applies commits oldest first, whatever order they were given, and records the origin' do
      run = pick('feat', shas['three'][0, 8], shas['one'][0, 8], '--yes')
      expect(run.status).to eq(0)
      expect(run.json['result']).to include('applied' => [shas['one'], shas['three']],
                                            'head' => head_sha)
      expect(subjects.first(2)).to eq(['Add three', 'Add one'])
      expect(git('log', '-1',
                 '--format=%B')).to include("(cherry picked from commit #{shas['three']})")
    end

    it 'undo returns to the starting point' do
      start = head_sha
      run = pick('feat', shas['one'], shas['two'], '--yes')
      expect(run.json['undo']['snapshot']).not_to be_nil
      run_cli('undo', '--yes')
      expect(head_sha).to eq(start)
    end

    it 'skips commits already on the branch and reports them' do
      git('cherry-pick', shas['one'])
      run = pick('feat', shas['one'], shas['two'], '--dry-run')
      expect(run.json['plan']).to include(
        'commits' => [shas['two']],
        'skipped' => [{ 'sha' => shas['one'], 'reason' => 'already on the current branch' }]
      )
      done = pick('feat', shas['one'], '--yes')
      expect(done.json['status']).to eq('noop')
    end

    it 'only stages the changes with --no-commit' do
      start = head_sha
      run = pick('feat', shas['one'], shas['two'], '--no-commit', '--yes')
      expect(run.json['plan']).to include('commit' => false)
      expect(head_sha).to eq(start)
      expect(git('status', '--porcelain')).to include('one.txt', 'two.txt')
    end

    it 'refuses unknown branches and commits, ambiguous or too short SHAs, and a missing source' do
      expect(pick('nope', '--list').json['error']).to include('code' => 'unknown_branch')
      expect(pick('-x', '--list').json['error']).to include('code' => 'unknown_branch')
      expect(pick('feat', 'f' * 40, '--yes').json['error']).to include('code' => 'unknown_commit')
      expect(pick('feat', shas['one'][0, 2], '--yes').json['error'])
        .to include('code' => 'unknown_commit')
      expect(pick('--json').json['error']).to include('code' => 'input_required')
      expect(pick('feat', '--yes').json['error']).to include('code' => 'input_required')
    end
  end

  describe 'conflicts' do
    it 'stops, lists the conflicted files and what is left, and leaves undo available' do
      conflicting, later = conflicting_branch(extra: 'later')
      start = head_sha
      run = pick('conf', conflicting, later, '--yes')

      expect(run.status).to eq(1)
      expect(run.json['status']).to eq('failed')
      expect(run.json['error']).to include('code' => 'conflict')
      expect(run.json['result']).to include('conflicted' => ['a.txt'], 'current' => conflicting,
                                            'remaining' => [later], 'applied' => [])
      expect(pick('conf', later, '--yes').json['error']).to include('code' => 'invalid_usage')

      run_cli('undo', run.json['undo']['snapshot'], '--yes')
      git('cherry-pick', '--abort')
      expect(head_sha).to eq(start)
    end

    it '--continue finishes the pick after the conflict is resolved' do
      conflicting, later = conflicting_branch(extra: 'later')
      pick('conf', conflicting, later, '--yes')
      File.write('a.txt', "resolved\n")
      git('add', 'a.txt')

      run = pick('--continue')
      expect(run.status).to eq(0)
      expect(run.json['result']).to include('action' => 'continue', 'head' => head_sha)
      expect(subjects.first(2)).to eq(['Add later', 'Change a on conf'])
    end

    it '--continue with the conflict still open reports it again' do
      conflicting, = conflicting_branch
      pick('conf', conflicting, '--yes')
      run = pick('--continue')
      expect(run.status).to eq(1)
      expect(run.json['error']).to include('code' => 'conflict')
    end

    it '--skip drops the conflicting commit and applies the rest, after confirmation' do
      conflicting, later = conflicting_branch(extra: 'later')
      pick('conf', conflicting, later, '--yes')
      expect(pick('--skip')).to have_attributes(status: 2)

      run = pick('--skip', '--yes')
      expect(run.status).to eq(0)
      expect(subjects.first(2)).to eq(['Add later', 'Change a on main'])
    end

    it '--abort returns to the state before the pick, after confirmation' do
      conflicting, = conflicting_branch
      start = head_sha
      pick('conf', conflicting, '--yes')
      expect(pick('--abort')).to have_attributes(status: 2)

      run = pick('--abort', '--yes')
      expect(run.json['result']).to include('action' => 'abort', 'head' => start)
      expect(git('status', '--porcelain')).to eq('')
    end

    it 'refuses control flags without a pick in progress, and several at once' do
      expect(pick('--continue').json['error']).to include('code' => 'invalid_usage')
      expect(pick('--abort', '--skip').json['error']).to include('code' => 'invalid_options')
    end
  end

  describe 'with a terminal' do
    let(:prompt) { instance_double(Gitflash::Prompt) }

    before do
      allow($stdin).to receive(:tty?).and_return(true)
      allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
    end

    it 'offers the other local branches when no source is given, then the commits' do
      git('branch', 'other')
      allow(prompt).to receive(:select) do |message, choices|
        expect(message).to eq('Select the branch to pick commits from')
        expect(choices).to eq(%w[feat other])
        'feat'
      end
      allow(prompt).to receive(:multi_select) do |_message, choices|
        expect(choices.values).to eq(shas.values_at('one', 'two', 'three'))
        [shas['two']]
      end
      allow(prompt).to receive(:proceed_with_warning) { |_message, &block| block.call }

      expect(run_cli('pick').stdout).to include('Applied 1 commit(s)')
      expect(subjects.first).to eq('Add two')
    end

    it 'lists the commits of the branch chosen from the menu with --list' do
      allow(prompt).to receive(:select).and_return('feat')
      stdout = run_cli('pick', '--list').stdout
      expect(stdout).to include('Add one')
      expect(stdout).to include('Add three')
    end

    it 'does not ask for a branch when one is given, and exits quietly when the menu has none' do
      allow(prompt).to receive(:select).and_raise('menu must not be shown')
      expect(run_cli('pick', 'feat', '--list').status).to eq(0)

      git('branch', '-D', 'feat')
      allow(prompt).to receive(:select).and_raise('menu must not be shown')
      run = run_cli('pick')
      expect(run).to have_attributes(status: 0, stdout: "You only have one branch!\n")
    end

    it 'still asks for the source without a terminal' do
      allow($stdin).to receive(:tty?).and_return(false)
      run = run_cli('pick', '--json')
      expect(run.status).to eq(2)
      expect(run.json['error']).to include('code' => 'input_required')
    end

    it 'offers the commits that are not on the branch yet and applies the chosen ones' do
      git('cherry-pick', shas['one'])
      allow(prompt).to receive(:multi_select) do |message, choices|
        expect(message).to eq('Select commits to pick (oldest first)')
        expect(choices.values).to eq([shas['two'], shas['three']])
        [shas['three']]
      end
      allow(prompt).to receive(:proceed_with_warning) { |_message, &block| block.call }

      expect(run_cli('pick', 'feat').stdout).to include('Applied 1 commit(s)')
      expect(subjects.first).to eq('Add three')
    end

    it 'shows author names from the source branch with control characters escaped' do
      git('switch', '-q', 'feat')
      ENV['GIT_AUTHOR_NAME'] = "Evil\e]52;c;ZXZpbA==\aName"
      commit_file('evil.txt')
      ENV.delete('GIT_AUTHOR_NAME')
      git('switch', '-q', 'main')

      labels = nil
      allow(prompt).to receive(:multi_select) do |_message, choices|
        labels = choices.keys
        []
      end
      run_cli('pick', 'feat')
      expect(labels.last).to include('Evil\\x1B]52;c;ZXZpbA==\\x07Name')
      expect(labels.join).not_to include("\e", "\a")
    end

    it 'says so when nothing is selected or nothing is left to pick' do
      allow(prompt).to receive(:multi_select).and_return([])
      allow(prompt).to receive(:proceed_with_warning) { |_message, &block| block.call }
      expect(run_cli('pick', 'feat').stdout).to eq("No commits selected\n")

      git('switch', '-q', 'feat')
      git('branch', 'same')
      expect(run_cli('pick', 'same').stdout).to eq("No commits to pick\n")
    end
  end
end
