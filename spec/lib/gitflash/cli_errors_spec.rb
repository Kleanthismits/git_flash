# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Cli, :git_repo do
  before { commit_file('a') }

  describe 'a bad command line' do
    it 'is a usage error with exit 2, in the JSON envelope with --json' do
      run = run_cli('mark', 'x', '--owner', 'bob', '--json')
      expect(run.status).to eq(2)
      expect(run.json).to include('command' => 'mark', 'ok' => false, 'status' => 'error')
      expect(run.json['error']).to include('code' => 'invalid_usage', 'exit_code' => 2)
    end

    it 'names subcommands as the envelope does, and an unknown command as gitflash' do
      expect(run_cli('wt', 'add', 'x', '--owner', 'bob', '--json').json['command'])
        .to eq('worktree add')
      expect(run_cli('nosuchcommand', '--json').json['command']).to eq('gitflash')
    end

    it 'takes --json=true and a command prefix Thor resolves' do
      run = run_cli('mar', 'x', '--owner', 'bob', '--json=true')
      expect(run.json).to include('command' => 'mark', 'status' => 'error')
    end

    it 'prints the message on stderr without --json' do
      run = run_cli('mark', 'x', '--owner', 'bob')
      expect(run).to have_attributes(status: 2, stdout: '')
      expect(run.stderr).to include('bob')
    end
  end

  it 'reports an unexpected error in the envelope instead of a stack trace' do
    allow_any_instance_of(Gitflash::Repo).to receive(:branches).and_raise(NoMethodError, 'boom')
    run = run_cli('branches', '--json')
    expect(run.status).to eq(1)
    expect(run.json['error']).to include('code' => 'failed')
    expect(run.json.dig('error', 'message')).to include('branches failed unexpectedly', 'boom')
  end

  describe 'a damaged snapshot ref' do
    before do
      run_cli('snapshot')
      junk = git('commit-tree', '-m', 'not a snapshot', git('write-tree').strip).strip
      git('update-ref', 'refs/gitflash/snapshots/99999999T000000000000-junk', junk)
    end

    it 'is skipped with a warning, so other snapshots still list and new ones are taken' do
      run = run_cli('snapshots', '--json')
      expect(run.json.dig('result', 'snapshots').size).to eq(1)
      expect(run.stderr).to include('skipping refs/gitflash/snapshots/99999999T000000000000-junk')
      commit_file('b')
      expect(run_cli('snapshot', '--json').json['status']).to eq('done')
    end
  end

  it 'refuses settings whose hooks value is null' do
    FileUtils.mkdir_p('.claude')
    File.write('.claude/settings.local.json', '{"hooks": null}')
    expect(run_cli('hook', 'status',
                   '--json').json['error']).to include('code' => 'invalid_settings')
  end

  it 'refuses settings whose root is not an object' do
    FileUtils.mkdir_p('.claude')
    File.write('.claude/settings.local.json', '[]')
    run = run_cli('hook', 'install', '--json')
    expect(run.json['error']).to include('code' => 'invalid_settings')
  end

  it 'reports a path with an unknown home directory as a usage error' do
    run = run_cli('wt', 'remove', '~gitflash-nosuchuser/x', '--json')
    expect(run.status).to eq(2)
    expect(run.json['error']).to include('code' => 'invalid_options')
  end
end
