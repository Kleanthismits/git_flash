RSpec.describe Gitflash::Git::Wrapper do
  let(:mock_bash) do
    allow(bash_command).to receive(:exec).with('git branch').and_return(branches)
    allow(bash_command).to receive(:exec).with('git branch --show-current').and_return('current')
  end

  it 'constants have proper values' do
    expect(described_class::HIDDEN_BRANCHES).to eq(%w[–show-current])
  end

  describe '.local branches' do
    it 'returns proper response with no arguments' do
      mock_bash

      expect(described_class.local_branches).to eq(%w[branch1 current main branch2 branch3])
    end

    it 'returns proper response with master false' do
      mock_bash

      expect(described_class.local_branches(master: false)).to eq(
        %w[branch1 current branch2 branch3]
      )
    end

    it 'returns proper response with current false' do
      mock_bash

      expect(described_class.local_branches(current: false)).to eq(
        %w[branch1 main branch2 branch3]
      )
    end

    it 'returns proper response with master and current false' do
      mock_bash

      expect(described_class.local_branches(master: false, current: false)).to eq(
        %w[branch1 branch2 branch3]
      )
    end
  end

  it '.all_local_branches returns proper response' do
    mock_bash

    expect(described_class.all_local_branches).to eq(%w[branch1 current main branch2 branch3])
  end

  it '.current_branch returns proper value' do
    mock_bash

    expect(described_class.current_branch).to eq('current')
  end

  def bash_command
    Gitflash::Git::BashCommand
  end

  def branches
    <<~BRANCHES
        branch1
      * current
        main
        branch2
        branch3
    BRANCHES
  end
end
