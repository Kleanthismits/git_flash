# frozen_string_literal: true

RSpec.describe Gitflash::CherryPick::LogParser do
  describe '.stat' do
    {
      ' 1 file changed, 1 insertion(+)' => [1, 1, 0],
      ' 3 files changed, 10 insertions(+), 2 deletions(-)' => [3, 10, 2],
      ' 2 files changed, 4 deletions(-)' => [2, 0, 4],
      "\n 1 file changed, 1 insertion(+)\n" => [1, 1, 0],
      '' => [0, 0, 0],
      'nothing like a stat line' => [0, 0, 0]
    }.each do |text, expected|
      it "reads #{text.inspect}" do
        expect(described_class.stat(text)).to eq(expected)
      end
    end

    it 'takes the last non-empty line' do
      expect(described_class.stat("junk\n 1 file changed, 2 insertions(+)\n\n")).to eq([1, 2, 0])
    end

    it 'handles a very long run of digits in linear time' do
      long = "#{'9' * 200_000} files changed, #{'9' * 200_000} insertions(+)"
      # Process.clock_gettime, not Benchmark: benchmark is not a default gem from Ruby 4.0
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      described_class.stat(long)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      expect(elapsed).to be < 1
    end
  end
end
