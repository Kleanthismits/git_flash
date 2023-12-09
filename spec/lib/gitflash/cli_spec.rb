RSpec.describe Gitflash::Cli do
  let(:cli) { described_class.new }

  describe '.exit_on_failure?' do
    it 'returns true' do
      expect(described_class.exit_on_failure?).to be true
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
