RSpec.describe Gitflash::Git::BashCommand do
  describe '.exec' do
    skip 'Find a way of testing the output commands without printing to actual stdout'
    it 'executes a shell command and returns the result' do
      command = 'echo "Hello, World!"'
      result = described_class.exec(command)
      expect(result).to eq("Hello, World!\n")
    end
  end

  describe '.system_exec' do
    it 'executes a shell command and returns true for success' do
      command = 'echo "Hello, World!"'
      expect { described_class.system_exec(command) }.to(
        output(a_string_including('Hello, World!')).to_stdout_from_any_process
      )
    end

    it 'executes an invalid shell command and prints the error' do
      command = 'non_existent_command'
      result = described_class.system_exec(command)
      expect(result).to be_nil
    end
  end
end
