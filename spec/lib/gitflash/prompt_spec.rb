RSpec.describe Gitflash::Prompt do
  describe '#create' do
    it 'creates a new instance of Gitflash::Prompt' do
      prompt = described_class.create
      expect(prompt).to be_a(described_class)
    end
  end

  describe 'methods' do
    let(:prompt) { described_class.new({}) }
    let(:message) { 'Select an option' }
    let(:collection) { ['Option 1', 'Option 2', 'Option 3'] }

    describe '#select' do
      it 'calls super with default select options' do
        expect_any_instance_of(TTY::Prompt).to receive(:select).with(
          message,
          collection,
          {
            cycle: true,
            per_page: 50,
            filter: true,
            symbols: { marker: '>' }
          }
        )

        prompt.select(message, collection)
      end

      it 'calls super with overridden select options' do
        expect_any_instance_of(TTY::Prompt).to receive(:select).with(
          message,
          collection,
          {
            cycle: true,
            per_page: 10,
            filter: false,
            symbols: { marker: '>' }
          }
        )

        prompt.select(message, collection, per_page: 10, filter: false)
      end
    end

    describe '#multi_select' do
      it 'calls super with default select options' do
        expect_any_instance_of(TTY::Prompt).to receive(:multi_select).with(
          message,
          collection,
          {
            cycle: true,
            per_page: 50,
            filter: true,
            symbols: { marker: '>' }
          }
        )

        prompt.multi_select(message, collection)
      end

      it 'calls super with overridden select options' do
        expect_any_instance_of(TTY::Prompt).to receive(:multi_select).with(
          message,
          collection,
          {
            cycle: true,
            per_page: 10,
            filter: false,
            symbols: { marker: '>' }
          }
        )

        prompt.multi_select(message, collection, per_page: 10, filter: false)
      end
    end

    describe '#proceed_with_warning' do
      let(:warning_message) { 'This is a warning message' }

      context 'user agrees' do
        before do
          allow(prompt).to receive(:warn)
          allow(prompt).to receive(:yes?).and_return(true)
        end

        it 'prints the warning message and proceeds' do
          expect_any_instance_of(TTY::Prompt).to receive(:warn).with(warning_message)
          expect(prompt).to receive(:yes?).with('Do you want to proceed?')

          expect(
            prompt.proceed_with_warning(warning_message) { puts '' }
          ).to be_nil
        end

        it 'yields to the block' do
          block_executed = false
          prompt.proceed_with_warning(warning_message) do
            block_executed = true
          end

          expect(block_executed).to be true
        end
      end

      context 'user disagrees' do
        before do
          allow(prompt).to receive(:warn)
          allow(prompt).to receive(:yes?).and_return(false)
        end

        it 'prints the warning message and does not proceed' do
          expect_any_instance_of(TTY::Prompt).to receive(:warn).with(warning_message)
          expect(prompt).to receive(:yes?).with('Do you want to proceed?')

          expect(
            prompt.proceed_with_warning(warning_message) { puts '' }
          ).to eq('Exited')
        end

        it 'does not yield to the block' do
          block_executed = false
          prompt.proceed_with_warning(warning_message) do
            block_executed = true
          end

          expect(block_executed).to be false
        end
      end
    end
  end
end
