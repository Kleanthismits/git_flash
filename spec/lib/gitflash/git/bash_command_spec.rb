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

  describe '.capture' do
    it 'returns stdout, stderr and success without raising' do
      stdout, stderr, success = described_class.capture('sh', '-c', 'echo 1; echo 2 >&2; exit 3')
      expect([stdout, stderr, success]).to eq(["1\n", "2\n", false])
    end

    it 'raises CommandError when the executable is missing' do
      expect { described_class.capture('non_existent_command') }.to raise_error(Gitflash::Git::CommandError)
    end
  end
end
