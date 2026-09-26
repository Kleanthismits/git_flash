# frozen_string_literal: true

RSpec.describe Gitflash::Hook::Claude, :git_repo do
  before do
    commit_file('a', "1\n")
    File.write('a', "edited\n")
  end

  def input(command, cwd: Dir.pwd, tool: 'Bash')
    JSON.generate(tool_name: tool, cwd: cwd, tool_input: { command: command })
  end

  def context(output)
    output.dig(:hookSpecificOutput, :additionalContext)
  end

  it 'saves one snapshot per directory and tells the agent how to undo' do
    output = described_class.new.call(input('git reset --hard && git clean -fd'))
    snapshot = Gitflash::Snapshots.new.list.first

    expect(Gitflash::Snapshots.new.list.size).to eq(1)
    expect(snapshot.scope).to eq(%w[branches head worktree])
    expect(snapshot.branches.keys).to eq(%w[main])
    expect(context(output)).to include("gitflash undo #{snapshot.id}")
    expect(output[:hookSpecificOutput]).not_to have_key(:permissionDecision)
  end

  it 'asks for approval in ask mode' do
    output = described_class.new(mode: 'ask').call(input('git clean -f'))
    expect(output[:hookSpecificOutput]).to include(permissionDecision: 'ask')
    expect(Gitflash::Snapshots.new.list.size).to eq(1)
  end

  it 'blocks without a snapshot in deny mode' do
    output = described_class.new(mode: 'deny').call(input('git checkout -- .'))
    expect(output[:hookSpecificOutput]).to include(permissionDecision: 'deny')
    expect(Gitflash::Snapshots.new.list).to eq([])
  end

  it 'does nothing for safe commands, other tools and non-repositories' do
    expect(described_class.new.call(input('git status'))).to be_nil
    expect(described_class.new.call(input('git reset --hard', tool: 'Edit'))).to be_nil
    Dir.mktmpdir do |dir|
      expect(described_class.new.call(input('git reset --hard', cwd: dir))).to be_nil
    end
  end
end
