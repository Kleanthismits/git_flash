# frozen_string_literal: true

require 'gitflash/mcp/server'

RSpec.describe Gitflash::Mcp::Server, :git_repo do
  subject(:server) { described_class.new }

  before do
    commit_file('a', "1\n")
    git('branch', 'feature')
  end

  def tool(name) = Gitflash::Mcp::Tools::ALL.find { |candidate| candidate.name == name }

  # A destructive tool's two calls: the plan with its token, then the change
  def confirmed(name, arguments)
    first = server.call(tool(name), arguments)
    expect(first).to include('status' => 'confirmation_required', 'ok' => false)
    server.call(tool(name), arguments.merge(confirm_token: first.dig('error', 'confirm_token')))
  end

  # A JSON-RPC request handled the way the stdio transport hands it over
  def rpc(method, params = {})
    server.mcp_server.handle({ jsonrpc: '2.0', id: 1, method: method, params: params })
  end

  describe 'the MCP server' do
    it 'lists every tool with hints that match its kind' do
      tools = rpc('tools/list')[:result][:tools]
      expect(tools.map { |entry| entry[:name] }).to eq(Gitflash::Mcp::Tools::ALL.map(&:name))
      delete = tools.find { |entry| entry[:name] == 'delete_branches' }
      expect(delete[:annotations]).to include(destructiveHint: true, readOnlyHint: false)
      expect(delete.dig(:inputSchema, :properties)).to include(:confirm_token)
      list = tools.find { |entry| entry[:name] == 'list_branches' }
      expect(list[:annotations]).to include(readOnlyHint: true, destructiveHint: false)
    end

    it 'answers with the JSON envelope as structured content' do
      result = rpc('tools/call', name: 'list_branches', arguments: { merged: true })[:result]
      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]).to include('command' => 'branches', 'ok' => true)
      expect(JSON.parse(result[:content].first[:text])).to eq(result[:structuredContent])
    end

    it 'refuses a name that starts with a dash before running anything' do
      result = rpc('tools/call', name: 'delete_branches', arguments: { branches: ['--force'] })
      expect(result.dig(:result, :isError)).to be(true)
      expect(branch_names).to eq(%w[feature main])
    end

    it 'passes the token through a real tools/call' do
      first = rpc('tools/call', name: 'delete_branches', arguments: { branches: ['feature'] })
      token = first.dig(:result, :structuredContent, 'error', 'confirm_token')
      second = rpc('tools/call', name: 'delete_branches',
                                 arguments: { confirm_token: token, branches: ['feature'] })
      expect(second.dig(:result, :structuredContent, 'status')).to eq('done')
      expect(branch_names).to eq(%w[main])
    end
  end

  describe 'destructive tools' do
    it 'change nothing on the first call and return the plan' do
      first = server.call(tool('delete_branches'), branches: ['feature'])
      expect(first['plan']).to eq('branches' => ['feature'], 'force' => false)
      expect(first['error']).to include('code' => 'confirmation_required', 'exit_code' => 2)
      expect(branch_names).to eq(%w[feature main])
    end

    it 'make the change with the token and return the undo' do
      result = confirmed('delete_branches', branches: ['feature'])
      expect(result).to include('status' => 'done')
      expect(result.dig('undo', 'command')).to start_with('gitflash undo ')
      expect(branch_names).to eq(%w[main])
    end

    it 'refuse a token for other arguments, and hand out a new one' do
      git('branch', 'other')
      token = server.call(tool('delete_branches'), branches: ['feature']).dig('error',
                                                                              'confirm_token')
      result = server.call(tool('delete_branches'), branches: ['other'], confirm_token: token)
      expect(result['status']).to eq('confirmation_required')
      expect(result.dig('error', 'message')).to include('does not match this plan')
      expect(result.dig('error', 'confirm_token')).not_to eq(token)
      expect(branch_names).to eq(%w[feature main other])
    end

    it 'refuse a token when the plan changed since it was issued' do
      commit_file('b', "2\n")
      git('checkout', '-q', '-b', 'topic')
      commit_file('c', "3\n")
      git('checkout', '-q', 'main')
      token = server.call(tool('reset_branch'), commit: 'topic', mode: 'hard').dig('error',
                                                                                   'confirm_token')
      git('branch', '-f', 'topic', 'feature')
      expect(server.call(tool('reset_branch'), commit: 'topic', mode: 'hard', confirm_token: token))
        .to include('status' => 'confirmation_required')
    end

    it 'refuse an expired token' do
      now = Time.now.to_i
      clock = -> { now }
      server = described_class.new(confirmation: Gitflash::Mcp::Confirmation.new(clock: clock))
      token = server.call(tool('delete_branches'), branches: ['feature']).dig('error',
                                                                              'confirm_token')
      now += Gitflash::Mcp::Confirmation::TTL + 1
      expect(server.call(tool('delete_branches'), branches: ['feature'], confirm_token: token))
        .to include('status' => 'confirmation_required')
      expect(branch_names).to eq(%w[feature main])
    end

    it 'return a refusal or nothing to do as it is, without a token' do
      result = server.call(tool('delete_branches'), branches: ['main'])
      expect(result['error']).not_to include('confirm_token')
      expect(server.call(tool('clean_branches'), gone: true)).to include('status' => 'noop')
    end

    it 'reset with a stable plan' do
      commit_file('b', "2\n")
      result = confirmed('reset_branch', commit: 'HEAD~1', mode: 'hard')
      expect(result['status']).to eq('done')
      expect(File).not_to exist('b')
    end

    it 'undo with a stable plan' do
      undo = confirmed('delete_branches', branches: ['feature'])['undo']
      expect(confirmed('undo', snapshot: undo['snapshot'])['status']).to eq('done')
      expect(branch_names).to eq(%w[feature main])
    end

    it 'clean branches with a stable plan' do
      expect(confirmed('clean_branches', merged: true)['status']).to eq('done')
      expect(branch_names).to eq(%w[main])
    end

    context 'with a worktree' do
      let(:worktree) { File.join(Dir.pwd, '..', "#{File.basename(Dir.pwd)}-wt") }

      before { git('worktree', 'add', '-q', worktree, 'feature') }
      after { FileUtils.rm_rf(worktree) }

      it 'moves it with a stable plan' do
        target = "#{worktree}-moved"
        result = confirmed('move_worktree', worktree: 'feature', path: target)
        expect(result['status']).to eq('done')
        expect(File).to exist(target)
      ensure
        FileUtils.rm_rf(target)
      end

      it 'removes one with ignored files, passing the token gitflash undo cannot cover' do
        File.write(File.join(worktree, '.gitignore'), "secret\n")
        File.write(File.join(worktree, 'secret'), "x\n")
        first = server.call(tool('remove_worktrees'), worktrees: ['feature'], force: true)
        expect(JSON.generate(first['plan'])).to include('secret')
        result = server.call(tool('remove_worktrees'),
                             worktrees: ['feature'], force: true,
                             confirm_token: first.dig('error', 'confirm_token'))
        expect(result['status']).to eq('done')
        expect(File).not_to exist(worktree)
      end
    end
  end

  describe 'destructive tools when the client can ask the user' do
    let(:elicitation) { instance_double(Gitflash::Mcp::Elicitation) }
    let(:server) { described_class.new(elicitation: elicitation) }
    let(:context) { Object.new }

    it 'make an approved change at once' do
      expect(elicitation).to receive(:ask)
        .with(context, tool('delete_branches'), { 'branches' => ['feature'], 'force' => false })
        .and_return(:accepted)
      result = server.call(tool('delete_branches'), { branches: ['feature'] }, context)
      expect(result['status']).to eq('done')
      expect(branch_names).to eq(%w[main])
    end

    it 'cancel a declined change without a token' do
      allow(elicitation).to receive(:ask).and_return(:declined)
      result = server.call(tool('delete_branches'), { branches: ['feature'] }, context)
      expect(result).to include('status' => 'cancelled', 'ok' => true)
      expect(result).not_to have_key('error')
      expect(branch_names).to eq(%w[feature main])
    end

    it 'fall back to the token when the user cannot be asked' do
      allow(elicitation).to receive(:ask).and_return(nil)
      result = server.call(tool('delete_branches'), { branches: ['feature'] }, context)
      expect(result.dig('error', 'confirm_token')).to be_a(String)
      expect(branch_names).to eq(%w[feature main])
    end

    it 'do not ask again when a token comes with the call' do
      expect(elicitation).not_to receive(:ask)
      result = server.call(tool('delete_branches'), { branches: ['feature'], confirm_token: '1.x' },
                           context)
      expect(result['status']).to eq('confirmation_required')
    end
  end

  describe 'other tools' do
    it 'run at once' do
      expect(server.call(tool('save_snapshot'), message: 'before')['status']).to eq('done')
      expect(server.call(tool('list_snapshots'), {})['result']).not_to be_empty
      expect(server.call(tool('mark_branches'), branches: ['feature'])['plan'])
        .to include('owner' => 'agent')
    end

    it 'add a worktree and return its absolute path' do
      result = server.call(tool('add_worktree'), branch: 'agent-1')
      path = result.dig('result', 'path')
      expect(path).to start_with('/')
      expect(server.call(tool('list_worktrees'), {})['result'].to_s).to include('agent-1')
    ensure
      FileUtils.rm_rf(path) if path
    end
  end

  describe 'a command that prints no JSON' do
    it 'is reported as a failed envelope' do
      runner = Gitflash::Mcp::Runner.new
      status = instance_double(Process::Status, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return(['oops', 'boom', status])
      expect(runner.call(%w[branches]))
        .to include('ok' => false, 'status' => 'error', 'error' => include('code' => 'failed'))
    end
  end
end
