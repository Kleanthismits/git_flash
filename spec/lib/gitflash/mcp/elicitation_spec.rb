# frozen_string_literal: true

require 'gitflash/mcp/server'

RSpec.describe Gitflash::Mcp::Elicitation do
  subject(:elicitation) { described_class.new(log: log) }

  let(:logged) { [] }
  let(:log) { ->(text) { logged << text } }

  let(:tool) { Gitflash::Mcp::Tools::ALL.find { |candidate| candidate.name == 'delete_branches' } }
  let(:plan) { { 'branches' => ['feature'], 'force' => false } }

  def ask_with(elicitation, context, tool, plan)
    elicitation.ask(context, tool, plan, state: -> { 'state' })
  end

  # A legacy server context whose client answers the form with `answer`, or runs `answer` when
  # it is a Proc; records the messages it was asked
  def context(answer, capabilities: { elicitation: {} })
    asked = []
    double = Object.new
    double.define_singleton_method(:modern?) { false }
    double.define_singleton_method(:client_capabilities) { capabilities }
    double.define_singleton_method(:asked) { asked }
    double.define_singleton_method(:create_form_elicitation) do |message:, requested_schema:|
      asked << [message, requested_schema]
      answer.is_a?(Proc) ? answer.call : answer
    end
    double
  end

  it 'is accepted on Accept, with the box ticked or left as it is' do
    [{ action: 'accept', content: { confirm: true } }, { 'action' => 'accept', 'content' => {} },
     { action: 'accept' }].each do |answer|
      expect(ask_with(elicitation, context(answer), tool, plan)).to eq(:accepted)
    end
  end

  it 'shows the plan on one line and a ticked, optional box' do
    accept = context({ action: 'accept' })
    ask_with(elicitation, accept, tool, plan)
    message, schema = accept.asked.first
    expect(message.lines.last).to eq('{"branches":["feature"],"force":false}')
    expect(schema).not_to have_key(:required)
    expect(schema.dig(:properties, :confirm, :default)).to be(true)
  end

  it 'is declined when the user declines, cancels or clears the box' do
    [{ action: 'decline' }, { action: 'cancel' },
     { action: 'accept', content: { confirm: false } }].each do |answer|
      expect(ask_with(elicitation, context(answer), tool, plan)).to eq(:declined)
    end
  end

  it 'cannot ask without the client capability or when disabled, and logs why' do
    expect(ask_with(elicitation, context({ action: 'accept' }, capabilities: {}), tool,
                    plan)).to be_nil
    disabled = described_class.new(enabled: false, log: log)
    expect(ask_with(disabled, context({ action: 'accept', content: { confirm: true } }), tool,
                    plan))
      .to be_nil
    expect(logged).to eq(
      ['delete_branches: not asking the user, the client did not declare the elicitation ' \
       'capability ({}); using the confirm_token',
       'delete_branches: not asking the user, started with --no-elicitation; using the ' \
       'confirm_token']
    )
  end

  it 'neither asks nor logs without a request context' do
    expect(ask_with(elicitation, nil, tool, plan)).to be_nil
    expect(logged).to be_empty
  end

  it 'gives up on an error, an unknown answer or no answer in time, and logs why' do
    expect(ask_with(elicitation, context(-> { raise 'client error' }), tool, plan)).to be_nil
    expect(ask_with(elicitation, context({ action: 'maybe' }), tool, plan)).to be_nil
    expect(ask_with(elicitation, context(nil), tool, plan)).to be_nil
    slow = described_class.new(timeout: 0.05, log: log)
    expect(ask_with(slow, context(-> { sleep 1 }), tool, plan)).to be_nil
    expect(logged).to match([/asking failed: RuntimeError: client error/, /unknown answer/,
                             /unknown answer nil/, /no answer within 0.05 seconds/])
  end

  it 'shows control characters from the repository as escapes' do
    accept = context({ action: 'decline' })
    ask_with(elicitation, accept, tool, { 'branches' => ["evil\u202Eexe"] })
    expect(accept.asked.first.first).to include('\\u202E')
    expect(accept.asked.first.first).not_to include("\u202E")
  end
end
