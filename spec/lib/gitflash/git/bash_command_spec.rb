# frozen_string_literal: true

RSpec.describe Gitflash::Git::BashCommand do
  describe '.exec' do
    let(:success) { instance_double(Process::Status, success?: true) }
    let(:failure) { instance_double(Process::Status, success?: false) }

    it 'runs the command without a shell and returns stdout' do
      allow(Open3).to receive(:capture3).with('git', 'branch').and_return(["main\n", '', success])
      expect(described_class.exec('git', 'branch')).to eq("main\n")
    end

    it 'raises CommandError with stderr when the command fails' do
      allow(Open3).to receive(:capture3).and_return(['', "fatal: not a git repository\n", failure])
      expect { described_class.exec('git', 'branch') }.to raise_error(
        Gitflash::Git::CommandError, 'git branch failed: fatal: not a git repository'
      )
    end

    it 'raises CommandError when the executable is missing' do
      expect { described_class.exec('non_existent_command') }.to raise_error(
        Gitflash::Git::CommandError, /non_existent_command failed/
      )
    end
  end

  describe '.system_exec' do
    it 'executes a command and prints its output' do
      expect { described_class.system_exec('echo', 'Hello, World!') }.to(
        output(a_string_including('Hello, World!')).to_stdout_from_any_process
      )
    end

    it 'returns nil for a missing executable' do
      expect(described_class.system_exec('non_existent_command')).to be_nil
    end
  end
end
