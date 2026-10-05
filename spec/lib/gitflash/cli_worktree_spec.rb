# frozen_string_literal: true

RSpec.describe Gitflash::Cli, :git_repo do
  describe 'worktree list' do
    before { commit_file('a.txt') }

    it 'prints the worktrees as JSON under both names' do
      %w[worktree wt].each do |name|
        run = run_cli(name, 'list', '--json')
        expect(run.status).to eq(0)
        expect(run.json).to include('command' => 'worktree list')
        expect(run.json['result']['worktrees'].first).to include('branch' => 'main', 'main' => true)
      end
    end

    it 'prints a table' do
      git('branch', 'other')
      expect(run_cli('wt', 'list').stdout).to match(/main\s+main/)
    end
  end
end
