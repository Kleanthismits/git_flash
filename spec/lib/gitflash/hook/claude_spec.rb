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

  it 'saves every branch when the command does not name the ones it deletes' do
    git('branch', 'one')
    git('branch', 'two')
    described_class.new.call(input('printf "one\\ntwo" | xargs git branch -D'))
    expect(Gitflash::Snapshots.new.list.first.branches.keys).to contain_exactly('main', 'one',
                                                                                'two')
  end

  it 'keeps saving every branch when an unnamed deletion shares a directory with a named one' do
    %w[a b c].each { |name| git('branch', name) }
    described_class.new.call(input('git branch -D a && printf "b" | xargs git branch -D'))
    expect(Gitflash::Snapshots.new.list.first.branches.keys).to include('a', 'b', 'c')
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

  it 'does nothing for safe commands and other tools' do
    expect(described_class.new.call(input('git status'))).to be_nil
    expect(described_class.new.call(input('git reset --hard', tool: 'Edit'))).to be_nil
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

  describe 'a home directory of an unknown user (`~nosuchuser`)' do
    let(:command) { 'cd ~gitflash-nosuchuser; git reset --hard' }

    it 'still blocks in deny mode' do
      output = described_class.new(mode: 'deny').call(input(command))
      expect(output[:hookSpecificOutput]).to include(permissionDecision: 'deny')
    end

    it 'reads git checkout and git -C without raising' do
      expect(described_class.new(mode: 'deny').call(input('git checkout ~gitflash-nosuchuser')))
        .to be_nil
      output = described_class.new(mode: 'deny')
                              .call(input('git -C ~gitflash-nosuchuser reset --hard'))
      expect(output[:hookSpecificOutput]).to include(permissionDecision: 'deny')
    end
  end

  describe 'a snapshot that fails' do
    let(:broken) do
      store = instance_double(Gitflash::Snapshots)
      allow(store).to receive(:create).and_raise('disk full')
      -> { store }
    end

    it 'still asks in ask mode, and says nothing was saved' do
      hook = described_class.new(mode: 'ask', snapshots: broken)
      output = nil
      expect { output = hook.call(input('git reset --hard')) }
        .to output(/could not save a snapshot.*disk full/).to_stderr
      expect(output[:hookSpecificOutput]).to include(permissionDecision: 'ask')
      expect(context(output)).to include('could not save a snapshot')
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

    it 'tells the agent in snapshot mode that nothing was saved, without asking' do
      Dir.mktmpdir do |dir|
        output = described_class.new.call(input('git reset --hard', cwd: dir))
        expect(output[:hookSpecificOutput]).not_to have_key(:permissionDecision)
        expect(context(output)).to include('could not save a snapshot', dir)
      end
    end
  end

  describe 'a directory the shell decides when it runs' do
    ['cd "$(git rev-parse --show-toplevel)" && git clean -fd', 'cd "$REPO" && git clean -fd',
     'cd `pwd` && git clean -fd', 'cd - && git clean -fd',
     'git -C "$REPO" clean -fd'].each do |command|
      it "snapshots the directory Claude runs in for #{command}" do
        output = described_class.new.call(input(command))
        expect(Gitflash::Snapshots.new.list.size).to eq(1)
        expect(context(output)).to include('gitflash undo')
      end
    end

    it 'says the directory was only guessed, next to the undo advice' do
      output = described_class.new.call(input('git -C "$REPO" clean -fd'))
      expect(context(output)).to include('gitflash undo', 'could only guess the directory',
                                         'another repository')
      plain = described_class.new.call(input('git clean -fd'))
      expect(context(plain)).not_to include('guess')
    end

    it 'names the commands it could not snapshot next to the ones it did' do
      Dir.mktmpdir do |dir|
        output = described_class.new.call(input("git clean -fd; git -C #{dir} clean -fd"))
        expect(context(output)).to include('gitflash undo', 'could not save a snapshot before ' \
                                                            "`git -C #{dir} clean -fd`")
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
