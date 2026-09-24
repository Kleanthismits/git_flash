# frozen_string_literal: true

RSpec.describe Gitflash::Repo, :git_repo do
  subject(:repo) { described_class.new }

  before do
    commit_file('a')
    commit_file('b')
  end

  describe '#ensure_work_tree!' do
    it 'passes inside a work tree' do
      expect { repo.ensure_work_tree! }.not_to raise_error
    end

    it 'raises outside a git repository' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect {
            described_class.new.ensure_work_tree!
          }.to raise_error(Gitflash::Error, 'Not a git repository')
        end
      end
    end
  end

  describe '#branches' do
    before do
      git('branch', 'merged-one')
      git('checkout', '-q', '-b', 'feature')
      commit_file('c', message: "Subject with\ttab and spaces")
      git('checkout', '-q', 'main')
    end

    it 'returns every local branch with its last commit' do
      feature = repo.branches.find { |branch| branch.name == 'feature' }

      expect(repo.branches.map(&:name)).to eq(%w[feature main merged-one])
      expect(feature).to have_attributes(
        current: false, default: false, upstream: nil, upstream_gone: false,
        ahead: 0, behind: 0, merged: nil, last_commit_author: 'Spec',
        last_commit_subject: "Subject with\ttab and spaces"
      )
      expect(feature.last_commit_at).to be_within(60).of(Time.now)
    end

    it 'marks the current and default branch' do
      main = repo.branches.find { |branch| branch.name == 'main' }
      expect(main).to have_attributes(current: true, default: true)
    end

    it 'reports merge status into the default branch on request' do
      merged = repo.branches(merged_status: true).to_h { |branch| [branch.name, branch.merged] }
      expect(merged).to eq('feature' => false, 'main' => true, 'merged-one' => true)
    end

    it 'reports upstream tracking' do
      git('branch', '--set-upstream-to=main', 'feature')
      feature = repo.branches.find { |branch| branch.name == 'feature' }

      expect(feature).to have_attributes(upstream: 'main', ahead: 1, behind: 0,
                                         upstream_gone: false)
    end

    it 'reports a deleted upstream as gone' do
      git('branch', 'temp')
      git('branch', '--set-upstream-to=temp', 'feature')
      git('branch', '-D', 'temp')
      feature = repo.branches.find { |branch| branch.name == 'feature' }

      expect(feature.upstream_gone).to be(true)
    end
  end

  describe '#default_branch' do
    it 'falls back to master when main does not exist' do
      git('branch', '-m', 'main', 'master')
      expect(repo.default_branch).to eq('master')
    end

    it 'is nil without main, master or origin/HEAD' do
      git('branch', '-m', 'main', 'trunk')
      expect(repo.default_branch).to be_nil
      expect(repo.branches(merged_status: true).map(&:merged)).to eq([nil])
    end

    it 'follows origin/HEAD' do
      git('branch', 'develop')
      git('update-ref', 'refs/remotes/origin/develop', 'develop')
      git('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/develop')

      expect(repo.default_branch).to eq('develop')
    end
  end

  describe '#current_branch' do
    it 'returns the checked out branch' do
      expect(repo.current_branch).to eq('main')
    end

    it 'is nil on a detached HEAD' do
      git('checkout', '-q', '--detach')
      expect(repo.current_branch).to be_nil
    end
  end

  describe '#commits' do
    it 'returns commits newest first' do
      expect(repo.commits.map(&:subject)).to eq(['Add b', 'Add a'])
      expect(repo.commits.first.label).to eq("#{head_sha[0, 7]} - Add b")
    end

    it 'respects the limit' do
      expect(repo.commits(limit: 1).size).to eq(1)
    end

    it 'is empty on a branch without commits' do
      git('checkout', '-q', '--orphan', 'empty')
      expect(repo.commits).to eq([])
    end
  end

  describe '#resolve_commit' do
    it 'returns the full sha of a reference' do
      expect(repo.resolve_commit('HEAD')).to eq(head_sha)
    end

    it 'returns nil for an unknown reference' do
      expect(repo.resolve_commit('nope')).to be_nil
    end
  end

  describe 'changes' do
    it 'checks out a branch even when a file has the same name' do
      git('branch', 'a')
      expect(repo.checkout('a')).to be_success
      expect(repo.current_branch).to eq('a')
    end

    it 'keeps an unmerged branch unless forced' do
      git('checkout', '-q', '-b', 'feature')
      commit_file('c')
      git('checkout', '-q', 'main')

      result = repo.delete_branch('feature')
      expect(result).not_to be_success
      expect(result.output).to include('not fully merged')
      expect(repo.delete_branch('feature', force: true)).to be_success
      expect(branch_names).to eq(%w[main])
    end

    it 'resets in the given mode' do
      first = git('rev-parse', 'HEAD~1').strip
      expect(repo.reset(first, mode: 'soft')).to be_success
      expect(head_sha).to eq(first)
      expect(git('diff', '--cached', '--name-only')).to eq("b\n")
    end
  end
end
