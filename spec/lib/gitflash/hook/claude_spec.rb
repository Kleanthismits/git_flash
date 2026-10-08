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

  it 'names the current branch correctly when a tag has the same name' do
    git('tag', 'main')

    described_class.new.call(input('git reset --hard'))
    expect(Gitflash::Snapshots.new.list.first.branches.keys).to eq(%w[main])
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

  describe 'PostToolUse' do
    def post(command, tool: 'Bash')
      JSON.generate(hook_event_name: 'PostToolUse', tool_name: tool, cwd: Dir.pwd,
                    tool_input: { command: command }, tool_response: { exit_code: 0 })
    end

    it 'marks the branch the command created and tells the agent' do
      git('checkout', '-q', '-b', 'feat')
      output = described_class.new.call(post('git checkout -b feat'))
      expect(output[:hookSpecificOutput]).to include(hookEventName: 'PostToolUse')
      expect(context(output)).to include('marked feat as agent work', 'gitflash mark BRANCH')
      expect(Gitflash::Ownership.new.all).to eq('feat' => 'agent')
    end

    it 'does nothing for other commands and tools, and never snapshots' do
      expect(described_class.new.call(post('git reset --hard'))).to be_nil
      expect(described_class.new.call(post('git checkout -b nope', tool: 'Edit'))).to be_nil
      expect(described_class.new.call(post('git checkout -b ghost'))).to be_nil
      expect(Gitflash::Snapshots.new.list).to be_empty
    end

    it 'leaves PreToolUse input without an event name working as before' do
      output = described_class.new.call(input('git reset --hard'))
      expect(context(output)).to include('gitflash undo')
    end
  end

  describe 'when the snapshot covers more than one directory' do
    it 'lists an undo command for every snapshot, with the directory it belongs to' do
      Dir.mktmpdir do |other|
        Dir.chdir(other) do
          git('init', '-q', '-b', 'main')
          git('config', 'user.name', 'Spec')
          git('config', 'user.email', 'spec@example.com')
          commit_file('b', "1\n")
        end
        command = "git reset --hard && cd #{other} && git reset --hard"
        output = described_class.new.call(input(command))

        here = Gitflash::Snapshots.new.list.map(&:id)
        there = Dir.chdir(other) { Gitflash::Snapshots.new.list.map(&:id) }
        expect([here.size, there.size]).to eq([1, 1])
        expect(context(output)).to include("`gitflash undo #{here.first}` (run in #{Dir.pwd})",
                                           "`gitflash undo #{there.first}` (run in #{other})")
      end
    end
  end

  describe 'a failure while recording branches' do
    it 'does not stop the snapshot or the decision' do
      broken = instance_double(Gitflash::Hook::BranchMarker)
      allow(broken).to receive(:record).and_raise(Errno::ENOSPC)

      hook = described_class.new(mode: 'ask', marker: broken)
      output = nil
      expect { output = hook.call(input('git reset --hard')) }
        .to output(/could not record branches/).to_stderr
      expect(output[:hookSpecificOutput]).to include(permissionDecision: 'ask')
      expect(Gitflash::Snapshots.new.list.size).to eq(1)
    end
  end

  describe 'ask mode outside a git work tree' do
    it 'still asks, because asking must not depend on a snapshot being saved' do
      Dir.mktmpdir do |dir|
        output = described_class.new(mode: 'ask').call(input('git reset --hard', cwd: dir))
        expect(output[:hookSpecificOutput]).to include(permissionDecision: 'ask')
        expect(context(output)).to include('could not save a snapshot', 'git reset --hard')
      end
    end

    it 'stays silent in snapshot mode when there is nothing to snapshot' do
      Dir.mktmpdir do |dir|
        expect(described_class.new.call(input('git reset --hard', cwd: dir))).to be_nil
      end
    end
  end

  describe 'branches recorded by PreToolUse' do
    it 'does not mark a branch that existed when the command started' do
      Dir.mktmpdir do |state|
        marker = Gitflash::Hook::BranchMarker.new(state_dir: state)
        hook = described_class.new(marker: marker)
        git('branch', 'human')
        id = 'toolu_x'
        pre = JSON.generate(tool_name: 'Bash', cwd: Dir.pwd, tool_use_id: id,
                            tool_input: { command: 'git branch human' })
        post = JSON.generate(hook_event_name: 'PostToolUse', tool_name: 'Bash', cwd: Dir.pwd,
                             tool_use_id: id, tool_input: { command: 'git branch human' })

        hook.call(pre)
        expect(hook.call(post)).to be_nil
        expect(Gitflash::Ownership.new.all).to eq({})
      end
    end
  end
end
