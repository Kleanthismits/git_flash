# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  let(:tty) { false }
  let(:prompt) { instance_double(Gitflash::Prompt) }

  before do
    allow($stdin).to receive(:tty?).and_return(tty)
    allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
    commit_file('a')
    commit_file('b')
    git('branch', 'merged-one')
    git('checkout', '-q', '-b', 'feature')
    commit_file('c')
    git('checkout', '-q', 'main')
  end

  def short_sha(ref)
    git('rev-parse', '--short', ref).strip
  end

  def names(json)
    json.dig('result', 'branches').map { |branch| branch['name'] }
  end

  it 'exits on failure' do
    expect(described_class.exit_on_failure?).to be true
  end

  describe 'version' do
    it 'prints the version for --version' do
      expect(run_cli('--version').stdout).to eq("#{Gitflash::VERSION}\n")
    end
  end

  describe 'schema' do
    it 'prints the JSON Schema without needing a repository' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect(JSON.parse(run_cli('schema').stdout)['title']).to include('schema version 1')
        end
      end
    end
  end

  describe 'outside a git repository' do
    it 'fails with exit code 1' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          run = run_cli('branches')
          expect(run).to have_attributes(status: 1, stderr: "Not a git repository\n")
        end
      end
    end

    it 'reports the error in the JSON envelope' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect(run_cli('branches', '--json').json).to eq(
            'schema' => 1, 'command' => 'branches', 'ok' => false, 'status' => 'error',
            'dry_run' => false,
            'error' => {
              'code' => 'not_a_repository', 'message' => 'Not a git repository', 'exit_code' => 1
            }
          )
        end
      end
    end
  end

  describe 'branches' do
    it 'prints a table' do
      stdout = run_cli('branches').stdout
      rows = stdout.lines.map { |line| line[0, 13].rstrip }
      expect(rows).to eq(['  feature', '* main', '  merged-one'])
      expect(stdout).to include('default').and include('merged')
    end

    it 'prints JSON' do
      json = run_cli('branches', '--json').json

      expect(json).to include('command' => 'branches', 'ok' => true, 'status' => 'done')
      expect(json.dig('result', 'default_branch')).to eq('main')
      expect(names(json)).to eq(%w[feature main merged-one])
      expect(json.dig('result', 'branches', 0, 'sha')).to eq(short_sha('feature'))
    end

    it 'filters merged branches, excluding the default branch' do
      expect(names(run_cli('branches', '--merged', '--json').json)).to eq(%w[merged-one])
    end

    it 'filters stale branches' do
      expect(names(run_cli('branches', '--stale', '1', '--json').json)).to eq([])
      expect(run_cli('branches', '--stale', '1').stdout).to eq("No branches match.\n")
    end

    it 'filters branches whose upstream is gone' do
      git('branch', 'temp')
      git('branch', '--set-upstream-to=temp', 'feature')
      git('branch', '-D', 'temp')

      expect(names(run_cli('branches', '--gone', '--json').json)).to eq(%w[feature])
    end
  end

  describe 'checkout' do
    it 'checks out the given branch' do
      expect(run_cli('checkout', 'feature', '--json').json).to eq(
        'schema' => 1, 'command' => 'checkout', 'ok' => true, 'status' => 'done',
        'dry_run' => false,
        'plan' => { 'branch' => 'feature' },
        'result' => { 'branch' => 'feature', 'previous_branch' => 'main' }
      )
      expect(git('branch', '--show-current')).to eq("feature\n")
    end

    it 'does nothing for the current branch' do
      expect(run_cli('checkout', 'main').stdout).to eq("Already on 'main'\n")
      json = run_cli('checkout', 'main', '--json').json
      expect(json).to include('ok' => true, 'status' => 'noop')
    end

    it 'does nothing with --dry-run' do
      stdout = run_cli('checkout', 'feature', '--dry-run').stdout
      expect(stdout).to eq("Would check out 'feature'\n")
      expect(run_cli('checkout', 'feature', '--dry-run', '--json').json).to include(
        'status' => 'planned', 'dry_run' => true, 'plan' => { 'branch' => 'feature' }
      )
      expect(git('branch', '--show-current')).to eq("main\n")
    end

    it 'rejects an unknown branch with exit code 2' do
      run = run_cli('checkout', 'nope')
      expect(run).to have_attributes(status: 2, stderr: "Unknown branch 'nope'\n")
      error = run_cli('checkout', 'nope', '--json').json['error']
      expect(error).to include('code' => 'unknown_branch')
    end

    it 'requires a branch without a terminal' do
      run = run_cli('checkout')
      expect(run).to have_attributes(status: 2, stderr: /Pass the branch to check out/)
      expect(run_cli('checkout', '--json').json['error']).to include('code' => 'input_required')
    end

    context 'with a terminal' do
      let(:tty) { true }

      it 'checks out the branch picked from the menu' do
        branches = %w[feature main merged-one]
        allow(prompt).to receive(:select)
          .with('Select a branch to checkout', branches, default: 'main').and_return('feature')

        expect(run_cli('checkout').stdout).to eq("Switched to branch 'feature'\n")
      end

      it 'does not pass a default on a detached HEAD' do
        git('checkout', '-q', '--detach')
        allow(prompt).to receive(:select)
          .with('Select a branch to checkout', %w[feature main merged-one]).and_return('main')

        expect(run_cli('checkout').status).to eq(0)
      end

      it 'says so when there is only one branch' do
        git('branch', '-D', 'feature', 'merged-one')
        expect(run_cli('checkout').stdout).to eq("You only have one branch!\n")
      end
    end
  end

  describe 'delete' do
    it 'requires --yes without a terminal and deletes nothing' do
      run = run_cli('delete', 'merged-one')
      expect(run).to have_attributes(status: 2, stderr: /Re-run with --yes to confirm/)
      expect(branch_names).to include('merged-one')
    end

    it 'returns the plan when confirmation is required' do
      json = run_cli('delete', 'merged-one', '--json').json

      expect(json).to include('ok' => false, 'status' => 'confirmation_required',
                              'plan' => { 'branches' => ['merged-one'], 'force' => false })
      expect(json['error']).to include('code' => 'confirmation_required', 'exit_code' => 2)
    end

    it 'deletes merged branches, keeps unmerged ones and reports how to restore' do
      sha = short_sha('merged-one')
      run = run_cli('delete', 'merged-one', 'feature', '--yes', '--json')

      expect(run.status).to eq(1)
      expect(run.json).to include('ok' => false, 'status' => 'failed')
      expect(run.json['error']).to include('code' => 'git_failed')
      expect(run.json.dig('result', 'deleted')).to eq([{ 'branch' => 'merged-one', 'sha' => sha }])
      expect(run.json.dig('result', 'failed')).to match([hash_including('branch' => 'feature')])
      expect(branch_names).to eq(%w[feature main])
    end

    it 'deletes unmerged branches with --force' do
      sha = short_sha('feature')
      run = run_cli('delete', 'feature', '--force', '--yes')
      expect(run).to have_attributes(status: 0, stdout: "Deleted branch feature (was #{sha})\n")
    end

    it 'shows the plan with --dry-run' do
      expect(run_cli('delete', 'feature', '--dry-run').stdout).to eq("Would delete:\n* feature\n")
      expect(branch_names).to include('feature')
    end

    it 'refuses protected branches' do
      expect(run_cli('delete', 'main', '--yes')).to have_attributes(
        status: 2, stderr: /protected branches: main/
      )
      expect(run_cli('delete', 'main', '--yes', '--json').json['error'])
        .to include('code' => 'protected_branch')
    end

    it 'refuses unknown branches' do
      run = run_cli('delete', 'nope', '--yes')
      expect(run).to have_attributes(status: 2, stderr: "Unknown branch: nope\n")
    end

    it 'requires branch names without a terminal' do
      run = run_cli('delete', '--yes')
      expect(run).to have_attributes(status: 2, stderr: /Pass the branches to delete/)
    end

    context 'with a terminal' do
      let(:tty) { true }

      it 'offers only unprotected branches and deletes the confirmed selection' do
        sha = short_sha('merged-one')
        allow(prompt).to receive(:multi_select)
          .with('Select branches to delete', %w[feature merged-one]).and_return(%w[merged-one])
        allow(prompt).to receive(:proceed_with_warning) { |_message, &block| block.call }

        expect(run_cli('delete').stdout).to eq("Deleted branch merged-one (was #{sha})\n")
      end

      it 'prints Exited when the user declines' do
        allow(prompt).to receive_messages(multi_select: %w[merged-one],
                                          proceed_with_warning: 'Exited')

        expect(run_cli('delete').stdout).to eq("Exited\n")
        expect(branch_names).to include('merged-one')
      end

      it 'says so when nothing is selected' do
        allow(prompt).to receive(:multi_select).and_return([])
        expect(run_cli('delete').stdout).to eq("No branches selected\n")
      end

      it 'says so when only protected branches exist' do
        git('branch', '-D', 'feature', 'merged-one')
        expect(run_cli('delete').stdout).to eq("No branches available to delete\n")
      end
    end
  end

  describe 'reset' do
    let!(:first) { git('rev-parse', 'HEAD~1').strip }

    it 'performs a mixed reset and reports the previous commit' do
      previous = head_sha

      expect(run_cli('reset', 'HEAD~1', '--json').json).to include(
        'command' => 'reset', 'ok' => true, 'status' => 'done',
        'plan' => { 'commit' => first, 'mode' => 'mixed' },
        'result' => { 'commit' => first, 'mode' => 'mixed', 'previous_commit' => previous }
      )
      expect(head_sha).to eq(first)
      expect(git('status', '--porcelain')).to eq("?? b\n")
    end

    it 'performs a soft reset' do
      run_cli('reset', 'HEAD~1', '--soft')
      expect(git('status', '--porcelain')).to eq("A  b\n")
    end

    it 'requires --yes for a hard reset without a terminal' do
      run = run_cli('reset', 'HEAD~1', '--hard')
      expect(run).to have_attributes(status: 2, stderr: /Re-run with --yes/)
      expect(head_sha).not_to eq(first)
    end

    it 'performs a hard reset with --yes' do
      run = run_cli('reset', 'HEAD~1', '--hard', '--yes')
      expect(run.stdout).to eq("Reset to #{first[0, 7]} (hard)\n")
      expect(git('status', '--porcelain')).to eq('')
    end

    it 'shows the plan with --dry-run' do
      run = run_cli('reset', 'HEAD~1', '--dry-run')
      expect(run.stdout).to eq("Would reset to #{first[0, 7]} (mixed)\n")
      expect(head_sha).not_to eq(first)
    end

    it 'rejects --soft together with --hard' do
      run = run_cli('reset', 'HEAD~1', '--soft', '--hard', '--json')
      expect(run.status).to eq(2)
      expect(run.json['error']).to include('code' => 'invalid_options')
    end

    it 'rejects an unknown commit' do
      run = run_cli('reset', 'nope')
      expect(run).to have_attributes(status: 2, stderr: "Unknown commit 'nope'\n")
      error = run_cli('reset', 'nope', '--json').json['error']
      expect(error).to include('code' => 'unknown_commit')
    end

    context 'with a terminal' do
      let(:tty) { true }

      it 'resets to the commit picked from the menu' do
        allow(prompt).to receive(:select) { |_message, choices| choices.values.last }
        expect(run_cli('reset').stdout).to eq("Reset to #{first[0, 7]} (mixed)\n")
      end

      it 'prints Exited when a hard reset is declined' do
        allow(prompt).to receive_messages(select: first, proceed_with_warning: 'Exited')
        expect(run_cli('reset', '--hard').stdout).to eq("Exited\n")
        expect(head_sha).not_to eq(first)
      end

      it 'says so when there is only one commit' do
        git('checkout', '-q', '--orphan', 'single')
        commit_file('only')
        expect(run_cli('reset').stdout).to eq("You only have one commit!\n")
      end
    end
  end

  describe 'help texts' do
    it 'loads descriptions for every command' do
      %w[branches checkout delete reset].each do |command|
        expect(described_class.descriptions.public_send(command).short).to be_a(String)
      end
    end
  end
end
