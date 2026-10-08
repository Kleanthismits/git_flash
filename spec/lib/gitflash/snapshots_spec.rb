# frozen_string_literal: true

RSpec.describe Gitflash::Snapshots, :git_repo do
  subject(:snapshots) { described_class.new }

  before do
    commit_file('a', "1\n")
    git('branch', 'feature')
  end

  def tree_files(commit)
    git('ls-tree', '-r', '--name-only', commit).split
  end

  describe '#create' do
    it 'saves branches, HEAD and a clean working tree without file commits' do
      snapshot = snapshots.create(reason: 'test')

      expect(snapshot).to have_attributes(
        reason: 'test', scope: %w[branches head worktree stashes], index: nil, worktree: nil,
        head: { branch: 'main', sha: head_sha },
        branches: { 'feature' => head_sha, 'main' => head_sha }
      )
      expect(snapshot.worktree_path).to eq(File.realpath(Dir.pwd))
      expect(git('for-each-ref', 'refs/gitflash/snapshots/')).to include(snapshot.id)
    end

    it 'saves untracked files named like pathspec magic or with spaces at either end' do
      names = [':(exclude)*', ':(top)x', ' lead', 'trail ', 'keep.txt']
      names.each { |name| File.write(name, name) }

      snapshot = snapshots.create(reason: 'odd names')
      saved = git('ls-tree', '-r', '--name-only', '-z', snapshot.worktree).split("\0")
      expect(saved).to include(*names)
    end

    it 'saves edited, staged and untracked files without changing them' do
      File.write('a', "edited\n")
      commit_file('b')
      File.write('staged', "s\n")
      git('add', 'staged')
      File.write('untracked', "u\n")
      status = git('status', '--porcelain')

      snapshot = snapshots.create(reason: 'test')

      expect(tree_files(snapshot.worktree)).to eq(%w[a b staged untracked])
      expect(tree_files(snapshot.index)).to eq(%w[a b staged])
      expect(git('show', "#{snapshot.worktree}:a")).to eq("edited\n")
      expect(git('status', '--porcelain')).to eq(status)
    end

    it 'skips ignored files and untracked files over the size limit' do
      stub_const('Gitflash::StateCapture::MAX_UNTRACKED_FILE_BYTES', 10)
      File.write('.gitignore', "ignored\n")
      File.write('ignored', "x\n")
      File.write('large', 'x' * 20)

      snapshot = snapshots.create(reason: 'test')

      expect(tree_files(snapshot.worktree)).to eq(%w[.gitignore a])
      expect(snapshot.skipped_files).to eq(%w[large])
    end

    it 'leaves out an untracked file that disappears while the snapshot is taken' do
      File.write('gone', "x\n")
      File.write('stays', "y\n")
      allow(File).to receive(:lstat).and_wrap_original do |original, path|
        raise Errno::ENOENT, path if path.end_with?('/gone')

        original.call(path)
      end

      snapshot = snapshots.create(reason: 'test', scope: %w[worktree])
      expect(tree_files(snapshot.worktree)).to eq(%w[a stays])
    end

    it 'saves stash entries' do
      File.write('a', "stashed\n")
      git('stash', '-q')
      expect(snapshots.create(reason: 'test').stashes).to eq([git('rev-parse', 'stash@{0}').strip])
    end

    it 'records only the requested scope and branches' do
      File.write('a', "edited\n")
      snapshot = snapshots.create(reason: 'test', scope: %w[branches], branches: %w[feature])

      expect(snapshot).to have_attributes(scope: %w[branches], branches: { 'feature' => head_sha },
                                          worktree: nil, stashes: [])
    end

    it 'returns the latest snapshot when nothing changed' do
      first = snapshots.create(reason: 'first')
      expect(snapshots.create(reason: 'second').id).to eq(first.id)

      File.write('a', "edited\n")
      expect(snapshots.create(reason: 'third').id).not_to eq(first.id)
    end

    it 'works before the first commit' do
      git('checkout', '-q', '--orphan', 'empty')
      git('rm', '-q', '--cached', 'a')
      snapshot = snapshots.create(reason: 'test', scope: %w[head worktree])

      expect(snapshot.head).to eq(branch: 'empty', sha: nil)
      expect(tree_files(snapshot.worktree)).to eq(%w[a])
    end

    it 'keeps saved commits reachable after their branch is deleted' do
      git('checkout', '-q', 'feature')
      commit_file('only-on-feature')
      tip = head_sha
      git('checkout', '-q', 'main')
      snapshots.create(reason: 'test')
      git('branch', '-D', 'feature')

      git('reflog', 'expire', '--expire-unreachable=now', '--all')
      git('gc', '-q', '--prune=now')
      expect(git('cat-file', '-t', tip)).to eq("commit\n")
    end
  end

  describe 'ordering' do
    it 'lists snapshots taken within the same second in the order they were taken' do
      times = [0.001r, 0.002r, 0.003r].map { |second| Time.utc(2026, 9, 27, 8, 0, second) }
      store = described_class.new(clock: -> { times.shift })
      ids = %w[one two three].map do |content|
        File.write('a', "#{content}\n")
        store.create(reason: content).id
      end

      expect(store.list.map(&:id)).to eq(ids.reverse)
    end
  end

  describe '#list, #find and #delete' do
    it 'lists newest first, finds by id and deletes' do
      old = snapshots.create(reason: 'old')
      File.write('a', "edited\n")
      new = snapshots.create(reason: 'new')

      expect(snapshots.list.map(&:id)).to eq([new.id, old.id])
      expect(snapshots.find(old.id)).to eq(old)
      snapshots.delete(old.id)
      expect(snapshots.list.map(&:id)).to eq([new.id])
    end
  end
end
