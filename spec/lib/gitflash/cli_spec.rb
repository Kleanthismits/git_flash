# frozen_string_literal: true

RSpec.describe Gitflash::Cli do
  let(:cli) { described_class.new([], cli_options) }
  let(:cli_options) { { hard: false } }
  let(:git) { Gitflash::Git::Wrapper }
  let(:prompt) { instance_double(Gitflash::Prompt) }

  before do
    allow(git).to receive(:inside_work_tree!)
  end

  describe '.exit_on_failure?' do
    it 'returns true' do
      expect(described_class.exit_on_failure?).to be true
    end
  end

  context 'when not inside a git repository' do
    before do
      allow(git).to receive(:inside_work_tree!).and_raise(Gitflash::Git::CommandError)
    end

    it 'raises a Thor::Error' do
      expect { cli.checkout }.to raise_error(Thor::Error, 'Not a git repository')
    end
  end

  describe '#checkout' do
    context 'when there are multiple branches' do
      it 'checks out the selected branch' do
        allow(cli).to receive(:branches?).and_return(true)
        expect(cli).to receive(:checkout_branch)
        cli.checkout
      end
    end

    context 'when there is only one branch' do
      it 'displays a message' do
        allow(cli).to receive(:branches?).and_return(false)
        expect { cli.checkout }.to output(/You only have one branch!/).to_stdout
      end
    end

    context 'when git checkout fails' do
      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(git).to receive_messages(all_local_branches: %w[main dev], current_branch: 'main',
                                       local_branches: %w[main dev], checkout: false)
        allow(prompt).to receive(:select).and_return('dev')
      end

      it 'raises a Thor::Error' do
        expect { cli.checkout }.to raise_error(Thor::Error, 'git checkout failed')
      end
    end

    context 'with a detached HEAD' do
      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(git).to receive_messages(all_local_branches: %w[main dev], current_branch: '',
                                       local_branches: %w[main dev], checkout: true)
      end

      it 'does not pass a default selection' do
        expect(prompt).to receive(:select).with('Select a branch to checkout', %w[main dev])
                                          .and_return('dev')
        cli.checkout
      end
    end
  end

  describe '#delete' do
    context 'when there are multiple branches' do
      it 'deletes selected branches' do
        allow(cli).to receive(:branches?).and_return(true)
        expect(cli).to receive(:delete_branch)
        cli.delete
      end
    end

    context 'when there is only one branch' do
      it 'displays a message' do
        allow(cli).to receive(:branches?).and_return(false)
        expect { cli.delete }.to output(/You only have one branch!/).to_stdout
      end
    end

    context 'when only protected branches exist' do
      it 'displays a message and deletes nothing' do
        allow(git).to receive_messages(all_local_branches: %w[main current], local_branches: [])
        expect(git).not_to receive(:delete)
        expect { cli.delete }.to output(/No branches available to delete/).to_stdout
      end
    end

    context 'when no branch is selected' do
      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(git).to receive_messages(all_local_branches: %w[main dev], local_branches: %w[dev])
        allow(prompt).to receive(:multi_select).and_return([])
      end

      it 'displays a message and deletes nothing' do
        expect(git).not_to receive(:delete)
        expect(prompt).to receive(:ok).with('No branches selected')
        cli.delete
      end
    end

    context 'when branches are selected and confirmed' do
      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(git).to receive_messages(all_local_branches: %w[main dev], local_branches: %w[dev])
        allow(prompt).to receive(:multi_select).and_return(%w[dev])
        allow(prompt).to receive(:proceed_with_warning) { |_message, &block| block.call }
      end

      it 'deletes the branches' do
        expect(git).to receive(:delete).with(%w[dev]).and_return(true)
        cli.delete
      end
    end
  end

  describe '#reset' do
    let(:commits) { { 'abc - second' => 'abc', 'def - first' => 'def' } }

    context 'when there is only one commit' do
      it 'displays a message' do
        allow(git).to receive(:branch_commits).and_return({ 'def - first' => 'def' })
        expect { cli.reset }.to output(/You only have one commit!/).to_stdout
      end
    end

    context 'with a soft reset' do
      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(prompt).to receive(:select).and_return('def')
      end

      it 'loads commits once and resets to the selected commit' do
        expect(git).to receive(:branch_commits).once.and_return(commits)
        expect(git).to receive(:reset).with(commit_hash: 'def', hard: false).and_return(true)
        cli.reset
      end
    end

    context 'with a hard reset' do
      let(:cli_options) { { hard: true } }

      before do
        allow(Gitflash::Prompt).to receive(:create).and_return(prompt)
        allow(git).to receive(:branch_commits).and_return(commits)
        allow(prompt).to receive_messages(select: 'def', proceed_with_warning: 'Exited')
      end

      it 'prints Exited when the user declines' do
        expect(git).not_to receive(:reset)
        expect { cli.reset }.to output("Exited\n").to_stdout
      end
    end
  end

  describe '#version' do
    it 'prints the gem version' do
      expect { cli.version }.to output("#{Gitflash::VERSION}\n").to_stdout
    end

    it 'is available as --version' do
      expect { described_class.start(['--version']) }.to output("#{Gitflash::VERSION}\n").to_stdout
    end
  end

  describe 'Configuration::Descriptions module' do
    let(:descriptions_hash) { YAML.load_file('command_descriptions.yml') }

    it 'loads descriptions from YAML file' do
      descriptions = described_class.descriptions
      expect(descriptions).to be_a(Struct)
    end

    it 'loads specific keys and values' do
      descriptions = described_class.descriptions

      expect(descriptions.checkout.short).to eq(descriptions_hash.dig('checkout', 'short'))
      expect(descriptions.checkout.long).to eq(descriptions_hash.dig('checkout', 'long'))
    end
  end
end
