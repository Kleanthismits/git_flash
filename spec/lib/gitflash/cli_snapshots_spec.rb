# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  let(:tty) { false }

  before do
    allow($stdin).to receive(:tty?).and_return(tty)
    commit_file('a', "1\n")
    git('branch', 'feature')
  end

  def snapshot_ids
    Gitflash::Snapshots.new.list.map(&:id)
  end

  describe 'undo after a gitflash change' do
    it 'recreates a deleted branch from the undo in the result' do
      undo = run_cli('delete', 'feature', '--yes', '--json').json['undo']
      expect(branch_names).to eq(%w[main])

      json = run_cli('undo', undo['snapshot'], '--yes', '--json').json
      expect(json).to include('status' => 'done', 'result' => { 'snapshot' => undo['snapshot'] })
      expect(json.dig('plan', 'branches'))
        .to eq([{ 'branch' => 'feature', 'from' => nil, 'to' => head_sha }])
      expect(branch_names).to eq(%w[feature main])
    end

    it 'restores the latest snapshot by default and can undo the undo' do
      File.write('a', "edited\n")
      run_cli('reset', 'HEAD', '--hard', '--yes')
      expect(File.read('a')).to eq("1\n")

      first = run_cli('undo', '--yes', '--json').json
      expect(File.read('a')).to eq("edited\n")

      run_cli('undo', first.dig('undo', 'snapshot'), '--yes')
      expect(File.read('a')).to eq("1\n")
    end

    it 'requires --yes without a terminal and shows the plan with --dry-run' do
      run_cli('delete', 'feature', '--yes')

      expect(run_cli('undo', '--json').json).to include('status' => 'confirmation_required')
      expect(run_cli('undo', '--dry-run').stdout).to include('recreate feature')
      expect(branch_names).to eq(%w[main])
    end
  end

  describe 'undo errors' do
    it 'is a noop without snapshots' do
      expect(run_cli('undo', '--json').json).to include('status' => 'noop')
    end

    it 'is a noop when the repository already matches' do
      run_cli('snapshot')
      expect(run_cli('undo', '--yes').stdout).to start_with('Nothing to undo')
    end

    it 'rejects an unknown snapshot' do
      error = run_cli('undo', 'nope', '--json').json['error']
      expect(error).to include('code' => 'unknown_snapshot')
    end

    it 'refuses to restore files of another worktree' do
      id = run_cli('snapshot', '--json').json.dig('undo', 'snapshot')
      Dir.mktmpdir do |dir|
        git('worktree', 'add', '-q', "#{dir}/wt", 'feature')
        Dir.chdir("#{dir}/wt") do
          error = run_cli('undo', id, '--yes', '--json').json['error']
          expect(error).to include('code' => 'wrong_worktree')
        end
      end
    end
  end

  describe 'snapshot and snapshots' do
    it 'saves on request and lists newest first' do
      first = run_cli('snapshot', '--message', 'before refactor', '--json').json
      expect(first.dig('result', 'snapshot')).to include('reason' => 'before refactor')

      File.write('a', "edited\n")
      second = run_cli('snapshot', '--scope', 'worktree', '--json').json
      expect(second.dig('result', 'snapshot', 'scope')).to eq(%w[worktree])

      ids = run_cli('snapshots', '--json').json.dig('result', 'snapshots').map { |s| s['id'] }
      expect(ids).to eq([second.dig('undo', 'snapshot'), first.dig('undo', 'snapshot')])
      expect(run_cli('snapshots').stdout).to include('before refactor')
    end

    it 'rejects an unknown scope' do
      error = run_cli('snapshot', '--scope', 'nope', '--json').json['error']
      expect(error).to include('code' => 'invalid_options')
    end
  end

  describe 'gc' do
    it 'deletes snapshots older than the given days' do
      run_cli('snapshot')
      expect(run_cli('gc', '--older-than', '1', '--json').json).to include('status' => 'noop')

      travel = Time.now + (3 * 86_400)
      allow(Time).to receive(:now).and_return(travel)
      expect(run_cli('gc', '--older-than', '1', '--json').json)
        .to include('status' => 'confirmation_required')
      deleted = run_cli('gc', '--older-than', '1', '--yes', '--json').json.dig('result', 'deleted')
      expect(deleted.size).to eq(1)
      expect(snapshot_ids).to eq([])
    end
  end

  describe 'hook claude' do
    it 'prints the Claude hook output for a destructive command' do
      input = JSON.generate(tool_name: 'Bash', cwd: Dir.pwd,
                            tool_input: { command: 'git branch -D feature' })
      allow($stdin).to receive(:read).and_return(input)

      output = JSON.parse(run_cli('hook', 'claude').stdout)
      expect(output.dig('hookSpecificOutput', 'additionalContext')).to include('gitflash undo')
    end

    it 'exits early for commands that do not mention git' do
      bin = File.expand_path('../../../bin/gitflash', __dir__)
      lib = File.expand_path('../../../lib', __dir__)
      input = JSON.generate(tool_name: 'Bash', tool_input: { command: 'ls -la' })
      stdout, _stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib, bin, 'hook', 'claude',
                                               stdin_data: input)
      expect([stdout, status.exitstatus]).to eq(['', 0])
    end

    it 'never fails the agent on bad input' do
      allow($stdin).to receive(:read).and_return('not json')
      expect(run_cli('hook', 'claude'))
        .to have_attributes(status: 0, stdout: '', stderr: /gitflash hook/)
    end
  end

  describe 'hook install' do
    let(:root) { File.realpath(Dir.pwd) }
    let(:settings) { File.join(root, '.claude', 'settings.local.json') }

    it 'adds the hook to the local settings and keeps other settings' do
      FileUtils.mkdir_p('.claude')
      File.write(settings, JSON.generate('permissions' => { 'allow' => ['Bash(ls)'] }))

      json = run_cli('hook', 'install', '--json').json
      expect(json).to include('command' => 'hook install', 'status' => 'done')
      expect(json['result']).to include('scope' => 'local', 'file' => settings)
      written = JSON.parse(File.read(settings))
      expect(written['permissions']).to eq('allow' => ['Bash(ls)'])
      expect(written.dig('hooks', 'PreToolUse', 0)).to eq(
        'matcher' => 'Bash',
        'hooks' => [{ 'type' => 'command', 'command' => 'gitflash hook claude', 'timeout' => 30 }]
      )
      expect(run_cli('hook', 'install', '--json').json).to include('status' => 'noop')
    end

    it 'also adds the PostToolUse hook that marks agent branches, once' do
      run_cli('hook', 'install')
      run_cli('hook', 'install', '--mode', 'ask')
      written = JSON.parse(File.read(settings))
      expect(written.dig('hooks', 'PostToolUse', 0)).to eq(
        'matcher' => 'Bash',
        'hooks' => [{ 'type' => 'command', 'command' => 'gitflash hook claude', 'timeout' => 30 }]
      )
      expect(written.dig('hooks', 'PostToolUse').size).to eq(1)
      expect(run_cli('hook', 'install', '--mode', 'ask', '--json').json['status']).to eq('noop')
    end

    it 'adds the PostToolUse hook to an install that only has PreToolUse' do
      FileUtils.mkdir_p('.claude')
      pre = { 'matcher' => 'Bash',
              'hooks' => [{ 'type' => 'command', 'command' => 'gitflash hook claude' }] }
      File.write(settings, JSON.generate('hooks' => { 'PreToolUse' => [pre] }))

      json = run_cli('hook', 'install', '--json').json
      expect(json['status']).to eq('done')
      written = JSON.parse(File.read(settings))
      expect(written.dig('hooks', 'PreToolUse')).to eq([pre])
      expect(written.dig('hooks', 'PostToolUse', 0, 'hooks', 0,
                         'command')).to eq('gitflash hook claude')
    end

    it 'says which sessions it applies to' do
      stdout = run_cli('hook', 'install').stdout
      expect(stdout).to include("Installed the gitflash hook in #{settings}")
      expect(stdout).to include("applies to Claude Code sessions in #{root}")
    end

    it 'writes the local settings at the main checkout from a linked worktree' do
      Dir.mktmpdir do |dir|
        git('worktree', 'add', '-q', "#{dir}/wt", 'feature')
        Dir.chdir("#{dir}/wt") { run_cli('hook', 'install') }
      end
      expect(File).to exist(settings)
    end

    it 'updates the mode of an installed hook' do
      run_cli('hook', 'install')
      run_cli('hook', 'install', '--mode', 'ask')
      hooks = JSON.parse(File.read(settings)).dig('hooks', 'PreToolUse')
      expect(hooks.size).to eq(1)
      expect(hooks.dig(0, 'hooks', 0, 'command')).to eq('gitflash hook claude --mode ask')
    end

    it 'writes the user settings from any directory' do
      Dir.mktmpdir do |home|
        allow(Dir).to receive(:home).and_return(home)
        Dir.chdir(home) { run_cli('hook', 'install', '--scope', 'user') }
        expect(File).to exist(File.join(home, '.claude', 'settings.json'))
      end
    end

    it 'refuses invalid settings files' do
      FileUtils.mkdir_p('.claude')
      File.write(settings, '{ nope')
      error = run_cli('hook', 'install', '--json').json['error']
      expect(error).to include('code' => 'invalid_settings')
    end
  end

  describe 'hook status' do
    let(:home) { Dir.mktmpdir }
    let(:bin) { Dir.mktmpdir }

    before do
      allow(Dir).to receive(:home).and_return(home)
      File.write(File.join(bin, 'gitflash'), '')
      File.chmod(0o755, File.join(bin, 'gitflash'))
      stub_const('ENV', ENV.to_h.merge('PATH' => "#{bin}:#{ENV.fetch('PATH')}"))
    end

    after { FileUtils.rm_rf([home, bin]) }

    def status_files(json)
      json.dig('result', 'files').to_h { |file| [file['scope'], file['installed']] }
    end

    it 'is not active before installing' do
      json = run_cli('hook', 'status', '--json').json
      expect(json).to include('command' => 'hook status', 'status' => 'done')
      expect(json.dig('result', 'active')).to be(false)
      expect(status_files(json)).to eq('local' => false, 'project' => false, 'user' => false)
      expect(run_cli('hook', 'status').stdout)
        .to start_with('gitflash hook: not active (run `gitflash hook install`)')
    end

    it 'says when branch marking is off in an older install' do
      FileUtils.mkdir_p('.claude')
      pre = { 'matcher' => 'Bash',
              'hooks' => [{ 'type' => 'command', 'command' => 'gitflash hook claude' }] }
      File.write('.claude/settings.local.json', JSON.generate('hooks' => { 'PreToolUse' => [pre] }))

      json = run_cli('hook', 'status', '--json').json
      expect(json['result']).to include('active' => true, 'marking' => false)
      expect(json.dig('result', 'files').first).to include('installed' => true, 'marking' => false)
      expect(run_cli('hook', 'status').stdout).to start_with(
        'gitflash hook: active (branch marking off: run `gitflash hook install` again)'
      )
    end

    it 'reports branch marking after a full install' do
      run_cli('hook', 'install')
      expect(run_cli('hook', 'status', '--json').json['result']).to include('marking' => true)
      expect(run_cli('hook',
                     'status').stdout).to start_with('gitflash hook: active, marks agent branches')
    end

    it 'is active after installing and names the executable' do
      run_cli('hook', 'install')
      json = run_cli('hook', 'status', '--json').json
      expect(json['result'])
        .to include('active' => true, 'executable' => File.join(bin, 'gitflash'))
      expect(status_files(json)).to include('local' => true)
    end

    it 'is not active when the gitflash executable is missing' do
      run_cli('hook', 'install')
      stub_const('ENV', ENV.to_h.merge('PATH' => '/nonexistent'))
      expect(run_cli('hook', 'status').stdout).to include('the gitflash executable is not on PATH')
    end

    it 'checks only the user settings outside a repository' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect(status_files(run_cli('hook', 'status', '--json').json)).to eq('user' => false)
        end
      end
    end
  end
end
