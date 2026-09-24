# frozen_string_literal: true

RSpec.describe Gitflash::Git::Wrapper do
  let(:current) { 'current' }

  before do
    allow(bash_command).to receive(:exec)
      .with('git', 'for-each-ref', '--format=%(refname:short)', 'refs/heads/')
      .and_return(branches)
    allow(bash_command).to receive(:exec)
      .with('git', 'branch', '--show-current')
      .and_return("#{current}\n")
  end

  describe '.local branches' do
    it 'returns proper response with no arguments' do
      expect(described_class.local_branches).to eq(%w[branch1 current main branch2 branch3])
    end

    it 'returns proper response with master false' do
      expect(described_class.local_branches(master: false)).to eq(
        %w[branch1 current branch2 branch3]
      )
    end

    it 'returns proper response with current false' do
      expect(described_class.local_branches(current: false)).to eq(
        %w[branch1 main branch2 branch3]
      )
    end

    it 'returns proper response with master and current false' do
      expect(described_class.local_branches(master: false, current: false)).to eq(
        %w[branch1 branch2 branch3]
      )
    end

    context 'with a detached HEAD' do
      let(:current) { '' }

      it 'returns all branches when current is excluded' do
        expect(described_class.local_branches(current: false)).to eq(
          %w[branch1 current main branch2 branch3]
        )
      end
    end
  end

  it '.all_local_branches returns proper response' do
    expect(described_class.all_local_branches).to eq(%w[branch1 current main branch2 branch3])
  end

  it '.current_branch returns proper value' do
    expect(described_class.current_branch).to eq('current')
  end

  describe '.checkout' do
    it 'checks out the branch' do
      expect(bash_command).to receive(:system_exec)
        .with('git', 'checkout', 'branch1', '--').and_return(true)
      expect(described_class.checkout('branch1')).to be(true)
    end
  end

  describe '.delete' do
    it 'deletes all given branches' do
      expect(bash_command).to receive(:system_exec)
        .with('git', 'branch', '-D', 'branch1', 'branch2').and_return(true)
      described_class.delete(%w[branch1 branch2])
    end
  end

  describe '.reset' do
    it 'performs a mixed reset' do
      expect(bash_command).to receive(:system_exec).with('git', 'reset', 'abc123', '--')
      described_class.reset(commit_hash: 'abc123', hard: false)
    end

    it 'performs a hard reset' do
      expect(bash_command).to receive(:system_exec).with('git', 'reset', '--hard', 'abc123', '--')
      described_class.reset(commit_hash: 'abc123', hard: true)
    end
  end

  describe '.branch_commits' do
    let(:log_args) { ['git', 'log', '--max-count=100', '--format=%h%x09%s'] }

    it 'parses hashes and subjects' do
      allow(bash_command).to receive(:exec).with(*log_args)
                                           .and_return("abc123\tFix bug\tin parser\ndef456\tInit\n")
      expect(described_class.branch_commits).to eq(
        "abc123 - Fix bug\tin parser" => 'abc123',
        'def456 - Init' => 'def456'
      )
    end

    it 'returns an empty hash when git log fails' do
      allow(bash_command).to receive(:exec).with(*log_args)
                                           .and_raise(Gitflash::Git::CommandError)
      expect(described_class.branch_commits).to eq({})
    end
  end

  def bash_command
    Gitflash::Git::BashCommand
  end

  def branches
    <<~BRANCHES
      branch1
      current
      main
      branch2
      branch3
    BRANCHES
  end
end
