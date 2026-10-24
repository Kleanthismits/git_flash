# frozen_string_literal: true

RSpec.describe Gitflash::Ui do
  let(:plan) { { snapshots: %w[a b] } }
  let(:token) { described_class.confirm_token(plan) }

  describe 'confirming a change gitflash undo cannot revert' do
    it 'is not covered by --yes and names the token in the error' do
      ui = described_class.new(command: 'gc', json: true, yes: true)
      expect { ui.confirm?('Delete', plan: plan, irreversible: true) }
        .to raise_error(Gitflash::ConfirmationRequired) { |error|
          expect(error.confirm_token).to eq(token)
          expect(error.message).to include("--confirm #{token}", '--yes is not enough')
        }
    end

    it 'goes ahead with the token of this plan only' do
      expect(described_class.new(command: 'gc', confirm: token)
               .confirm?('Delete', plan: plan, irreversible: true)).to be(true)
      other = described_class.new(command: 'gc', json: true, confirm: token)
      expect { other.confirm?('Delete', plan: { snapshots: %w[c] }, irreversible: true) }
        .to raise_error(Gitflash::ConfirmationRequired)
    end

    it 'asks for the token in a terminal instead of yes or no' do
      ui = described_class.new(command: 'gc')
      prompt = instance_double(Gitflash::Prompt)
      allow(ui).to receive_messages(interactive?: true, prompt: prompt)
      allow(prompt).to receive(:ask).and_return(token, 'y')
      expect { expect(ui.confirm?('Delete', plan: plan, irreversible: true)).to be(true) }
        .to output(/cannot revert/).to_stderr
      expect { expect(ui.confirm?('Delete', plan: plan, irreversible: true)).to be(false) }
        .to output.to_stderr
    end
  end

  it 'still takes --yes for a change gitflash undo can revert' do
    expect(described_class.new(command: 'delete', yes: true).confirm?('Delete', plan: plan))
      .to be(true)
  end
end
