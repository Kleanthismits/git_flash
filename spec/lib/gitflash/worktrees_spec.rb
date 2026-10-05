# frozen_string_literal: true

RSpec.describe Gitflash::Worktrees, :git_repo do
  subject(:worktrees) { described_class.new(repo: Gitflash::Repo.new) }

  let(:outside) { Dir.mktmpdir('gitflash-wt') }

  before { commit_file('a.txt') }
  after { FileUtils.remove_entry(outside) }

  def real(path) = File.realpath(path)

  it 'lists the main checkout alone' do
    expect(worktrees.list).to contain_exactly(
      have_attributes(path: real(Dir.pwd), branch: 'main', main?: true, dirty?: false,
                      locked?: false, missing?: false, merged: true)
    )
  end

  it 'lists linked worktrees with branch, dirty, lock and missing state' do
    git('worktree', 'add', '-q', '-b', 'feat', File.join(outside, 'feat'))
    git('worktree', 'add', '-q', '--detach', File.join(outside, 'det'))
    git('worktree', 'add', '-q', '-b', 'gone', File.join(outside, 'gone'))
    git('worktree', 'lock', '--reason', 'in use', File.join(outside, 'det'))
    File.write(File.join(outside, 'feat', 'new.txt'), 'x')
    FileUtils.rm_rf(File.join(outside, 'gone'))

    by_branch = worktrees.list.to_h { |worktree| [worktree.branch || 'detached', worktree] }
    expect(by_branch['feat']).to have_attributes(main?: false, dirty?: true, merged: true)
    expect(by_branch['detached']).to have_attributes(locked?: true, lock_reason: 'in use',
                                                     dirty?: false, merged: nil)
    expect(by_branch['gone']).to have_attributes(missing?: true, dirty?: nil)
  end

  it 'keeps a path with a newline and a lock reason with odd characters intact' do
    path = File.join(outside, "line\nbreak")
    git('worktree', 'add', '-q', '-b', 'odd', path)
    git('worktree', 'lock', '--reason', "two\nlines ünï", path)
    odd = worktrees.list.find { |worktree| worktree.branch == 'odd' }
    expect(odd).to have_attributes(path: real(path), locked?: true, lock_reason: "two\nlines ünï")
  end

  it 'reuses a registered but missing directory given under a symlinked spelling' do
    real = File.join(File.realpath(outside), 'real')
    FileUtils.mkdir_p(real)
    File.symlink(real, File.join(outside, 'link'))
    git('worktree', 'add', '-q', '-b', 'gone', File.join(real, 'gone'))
    FileUtils.rm_rf(File.join(real, 'gone'))

    result = worktrees.attach(File.join(outside, 'link', 'gone'), branch: 'gone')
    expect(result.success?).to be(true), result.output
    expect(File.directory?(File.join(real, 'gone'))).to be(true)
  end

  it 'reports a branch with unmerged commits as not merged' do
    git('worktree', 'add', '-q', '-b', 'work', File.join(outside, 'work'))
    Dir.chdir(File.join(outside, 'work')) { commit_file('b.txt') }
    expect(worktrees.list.find { |worktree| worktree.branch == 'work' }.merged).to be(false)
  end
end
