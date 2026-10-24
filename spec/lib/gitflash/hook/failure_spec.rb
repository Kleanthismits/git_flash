# frozen_string_literal: true

RSpec.describe Gitflash::Hook::Failure do
  let(:error) { RuntimeError.new('boom') }
  let(:pre) { JSON.generate(tool_name: 'Bash', tool_input: { command: 'git reset --hard' }) }
  let(:post) { JSON.generate(hook_event_name: 'PostToolUse', tool_name: 'Bash') }

  it 'asks or blocks in ask and deny mode, also when the input is not JSON' do
    expect(described_class.output('ask', error, pre)[:hookSpecificOutput])
      .to include(hookEventName: 'PreToolUse', permissionDecision: 'ask')
    expect(described_class.output('deny', error, 'not json')[:hookSpecificOutput])
      .to include(permissionDecision: 'deny', permissionDecisionReason: /could not check.*boom/)
  end

  it 'stays silent in snapshot mode and after the command (PostToolUse)' do
    expect(described_class.output('snapshot', error, pre)).to be_nil
    expect(described_class.output('deny', error, post)).to be_nil
  end
end
