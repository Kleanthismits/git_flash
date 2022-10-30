RSpec.describe Gitflash::Prompt do
  describe '.create' do
    let(:prompt) { described_class.create }

    it 'sets default create options' do
      expect(TTY::Prompt).to receive(:new).with({
                                                  interrupt: :exit,
                                                  quiet: true
                                                })

      prompt
    end
  end

  describe '#select' do
    let(:prompt) { described_class.new({}) }
    let(:message) { 'Select an option' }
    let(:collection) { ['Option 1', 'Option 2', 'Option 3'] }

    context 'when default select options are used' do
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
    end

    context 'when default select options are overridden' do
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
  end
end
