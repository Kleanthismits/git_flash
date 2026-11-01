# frozen_string_literal: true

require 'gitflash/mcp/server'

RSpec.describe Gitflash::Mcp::Elicitation do
  subject(:elicitation) { described_class.new(log: log) }

  let(:logged) { [] }
  let(:log) { ->(text) { logged << text } }

  let(:tool) { Gitflash::Mcp::Tools::ALL.find { |candidate| candidate.name == 'delete_branches' } }
  let(:plan) { { 'branches' => ['feature'], 'force' => false } }

  # A server context whose client answers the form with `answer`, or runs `answer` when it is
  # a Proc; records the messages it was asked
  def context(answer, capabilities: { elicitation: {} })
    asked = []
    double = Object.new
    double.define_singleton_method(:client_capabilities) { capabilities }
    double.define_singleton_method(:asked) { asked }
    double.define_singleton_method(:create_form_elicitation) do |message:, requested_schema:|
      asked << [message, requested_schema]
      answer.is_a?(Proc) ? answer.call : answer
    end
    double
  end

  it 'is accepted only when the user ticks the box' do
    accept = context({ action: 'accept', content: { confirm: true } })
    expect(elicitation.ask(accept, tool, plan)).to eq(:accepted)
    message, schema = accept.asked.first
    expect(message).to include('delete_branches', '"feature"')
    expect(schema[:required]).to eq(%w[confirm])
  end

  it 'is declined when the user declines, cancels or leaves the box empty' do
    [{ action: 'decline' }, { action: 'cancel' }, { action: 'accept', content: { confirm: false } },
     { 'action' => 'accept', 'content' => {} }].each do |answer|
      expect(elicitation.ask(context(answer), tool, plan)).to eq(:declined)
    end
  end

  it 'cannot ask without the client capability or when disabled, and logs why' do
    expect(elicitation.ask(context({ action: 'accept' }, capabilities: {}), tool, plan)).to be_nil
    disabled = described_class.new(enabled: false, log: log)
    expect(disabled.ask(context({ action: 'accept', content: { confirm: true } }), tool, plan))
      .to be_nil
    expect(logged).to eq(
      ['delete_branches: not asking the user, the client did not declare the elicitation ' \
       'capability ({}); using the confirm_token',
       'delete_branches: not asking the user, started with --no-elicitation; using the ' \
       'confirm_token']
    )
  end

  it 'neither asks nor logs without a request context' do
    expect(elicitation.ask(nil, tool, plan)).to be_nil
    expect(logged).to be_empty
  end

  it 'gives up on an error, an unknown answer or no answer in time, and logs why' do
    expect(elicitation.ask(context(-> { raise 'client error' }), tool, plan)).to be_nil
    expect(elicitation.ask(context({ action: 'maybe' }), tool, plan)).to be_nil
    expect(elicitation.ask(context(nil), tool, plan)).to be_nil
    slow = described_class.new(timeout: 0.05, log: log)
    expect(slow.ask(context(-> { sleep 1 }), tool, plan)).to be_nil
    expect(logged).to match([/asking failed: RuntimeError: client error/, /unknown answer/,
                             /unknown answer nil/, /no answer within 0.05 seconds/])
  end

  it 'shows control characters from the repository as escapes' do
    accept = context({ action: 'decline' })
    elicitation.ask(accept, tool, { 'branches' => ["evil\u202Eexe"] })
    expect(accept.asked.first.first).to include('\\u202E')
    expect(accept.asked.first.first).not_to include("\u202E")
  end
end
