# frozen_string_literal: true

RSpec.describe Gitflash::Hook::CommandParser do
  subject(:parser) { described_class.new('/repo') }

  def targets(command)
    parser.targets(command).map { |target| [target.dir, target.scope, target.branches] }
  end

  {
    'git reset --hard HEAD~1' => [['/repo', %w[branches head worktree], [:current]]],
    'git checkout -- .' => [['/repo', %w[worktree], []]],
    'git checkout -f main' => [['/repo', %w[worktree], []]],
    'git restore src/app.rb' => [['/repo', %w[worktree], []]],
    'git clean -fdx' => [['/repo', %w[worktree], []]],
    'git switch --discard-changes main' => [['/repo', %w[head worktree], []]],
    'git stash drop' => [['/repo', %w[stashes], []]],
    'git stash pop' => [['/repo', %w[worktree stashes], []]],
    'git branch -D old other' => [['/repo', %w[branches], %w[old other]]],
    'git update-ref -d refs/heads/old' => [['/repo', %w[branches], %w[old]]],
    'git rebase main' => [['/repo', %w[branches head worktree], [:current]]],
    'git merge --abort' => [['/repo', %w[worktree], []]],
    'git worktree remove --force ../wt' => [['/wt', %w[worktree], []]],
    'git branch -qD old' => [['/repo', %w[branches], %w[old]]],
    'git branch -fq old' => [['/repo', %w[branches], %w[old]]],
    'git clean -i' => [['/repo', %w[worktree], []]],
    'bash -c "cd /other && git reset --hard"' => [['/other', %w[branches head worktree],
                                                   [:current]]],
    "sh -lc 'git clean -fd'" => [['/repo', %w[worktree], []]],
    'eval "git branch -D old"' => [['/repo', %w[branches], %w[old]]],
    'if true; then git reset --hard; fi' => [['/repo', %w[branches head worktree], [:current]]],
    'for b in x; do git branch -D old; done' => [['/repo', %w[branches], %w[old]]],
    'for b in x y; do git branch -D "$b"; done' => [['/repo', %w[branches], []]],
    'while git stash pop; do :; done' => [['/repo', %w[worktree stashes], []]],
    '! git clean -f' => [['/repo', %w[worktree], []]],
    'echo $(git clean -f)' => [['/repo', %w[worktree], []]],
    'echo `git stash clear`' => [['/repo', %w[stashes], []]],
    'x=$(echo $(git stash drop))' => [['/repo', %w[stashes], []]],
    'diff <(git stash drop) file' => [['/repo', %w[stashes], []]],
    'echo "a\\"b" ; git clean -f' => [['/repo', %w[worktree], []]],
    'cd /other && echo $(git clean -f)' => [['/other', %w[worktree], []]],
    %q{echo "it's $(git clean -f)"} => [['/repo', %w[worktree], []]],
    'echo `printf \\` && git clean -f`' => [['/repo', %w[worktree], []]],
    'echo $(printf ")" && git clean -f)' => [['/repo', %w[worktree], []]],
    "echo $(printf ')' && git clean -f)" => [['/repo', %w[worktree], []]],
    'echo $(echo $(echo $(echo $(git clean -f))))' => [['/repo', %w[branches head worktree], []]],
    'git worktree remove ../wt' => [['/wt', %w[worktree], []]],
    'git rm -f a' => [['/repo', %w[worktree], []]],
    'git rm -rf dir' => [['/repo', %w[worktree], []]],
    'git checkout-index -f -a' => [['/repo', %w[worktree], []]],
    'git read-tree -u --reset HEAD' => [['/repo', %w[worktree], []]],
    'git reflog expire --expire=now --all' => [['/repo', %w[branches head worktree], []]],
    'git reflog delete HEAD@{1}' => [['/repo', %w[branches head worktree], []]],
    'git gc --prune=now' => [['/repo', %w[branches head worktree], []]],
    'git prune' => [['/repo', %w[branches head worktree], []]],
    'git push . :old' => [['/repo', %w[branches], %w[old]]],
    'git push . :refs/heads/old' => [['/repo', %w[branches], %w[old]]],
    'git push . --delete old other' => [['/repo', %w[branches], %w[old other]]],
    'git update-ref --stdin < cmds' => [['/repo', %w[branches], []]],
    'for b in x; do git push . --delete "$b"; done' => [['/repo', %w[branches], []]],
    'xargs -I{} git push . :{}' => [['/repo', %w[branches], []]],
    'xargs git push . --delete' => [['/repo', %w[branches], []]]
  }.each do |command, expected|
    it "reports `#{command}`" do
      expect(targets(command)).to eq(expected)
    end
  end

  [
    'git status', 'git commit -m "wip"', 'git checkout main', 'git clean -n', 'git clean -fn',
    'git stash', 'git branch new', 'git rebase --continue', 'git push --force', 'ls -la',
    'echo "git reset --hard"', 'git rm --cached -f a', 'git rm a', 'git checkout-index -a',
    'git read-tree -u -m HEAD', 'git reflog show', 'git gc', 'git push origin :old',
    'git push . main:other', "echo '$(git reset --hard)'",
    'echo \\$(git reset --hard)', 'echo "\\`git stash clear\\`"', 'echo "<(git stash drop)"',
    'echo $(echo $(echo $(echo $(ls))))'
  ].each do |command|
    it "ignores `#{command}`" do
      expect(targets(command)).to eq([])
    end
  end

  it 'falls back to the directory Claude runs in when the shell decides the path' do
    expect(targets('cd "$(git rev-parse --show-toplevel)" && git reset --hard').first.first)
      .to eq('/repo')
    expect(targets('cd sub; git -C "$X" clean -f; cd -; git clean -f').map(&:first))
      .to eq(%w[/repo /repo])
  end

  it 'marks the targets whose directory is a guess, also after a relative cd' do
    guessed = ->(command) { parser.targets(command).map(&:guessed) }
    expect(guessed.call('cd "$R"; git clean -f; cd sub; git clean -f; cd /abs; git clean -f'))
      .to eq([true, true, false])
    expect(guessed.call('git -C "$R" worktree remove --force wt')).to eq([true])
    expect(guessed.call('git clean -f')).to eq([false])
  end

  it 'follows cd and git -C' do
    expect(targets('cd sub && git clean -f; git -C /other reset --hard')).to eq(
      [['/repo/sub', %w[worktree], []], ['/other', %w[branches head worktree], [:current]]]
    )
  end

  it 'ignores separators inside quotes' do
    expect(targets('git commit -m "fix; git reset --hard" && git status')).to eq([])
  end

  it 'sees force and patch options bundled with other short options' do
    expect(targets('git checkout -fq main')).to eq([['/repo', %w[worktree], []]])
    expect(targets('git switch -fq main')).to eq([['/repo', %w[head worktree], []]])
    expect(targets('git checkout -pq main')).to eq([['/repo', %w[worktree], []]])
    expect(targets('git checkout -q main')).to eq([])
  end

  it 'treats `git checkout PATH` as a discard when PATH exists' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'app.rb'), 'x')
      parser = described_class.new(dir)

      expect(parser.targets('git checkout app.rb').map(&:scope)).to eq([%w[worktree]])
      expect(parser.targets('git checkout main')).to eq([])
    end
  end

  it 'skips environment assignments and wrappers' do
    expect(targets('GIT_TRACE=1 sudo git clean -f')).to eq([['/repo', %w[worktree], []]])
  end

  describe 'wrapped commands' do
    reset = ['/repo', %w[branches head worktree], [:current]]
    {
      '/usr/bin/env git reset --hard' => reset,
      'env -i git reset --hard' => reset,
      'env -u HOME FOO=1 git reset --hard' => reset,
      'sudo -u me git reset --hard' => reset,
      'command -p git reset --hard' => reset,
      'timeout 5 git reset --hard' => reset,
      'timeout -s KILL 5s git reset --hard' => reset,
      'nice -n 5 nohup git reset --hard' => reset,
      'xargs git branch -D < list' => ['/repo', %w[branches], []],
      'xargs -n 1 git branch -D' => ['/repo', %w[branches], []],
      'find . -name x -exec git checkout -- {} \\;' => ['/repo', %w[worktree], []],
      'git branch -D old >/dev/null 2>&1' => ['/repo', %w[branches], %w[old]],
      'sudo -D /d git clean -f' => ['/d', %w[worktree], []],
      'env -C /e git clean -f' => ['/e', %w[worktree], []],
      'pushd /p && git clean -f' => ['/p', %w[worktree], []]
    }.each do |command, expected|
      it "reports `#{command}`" do
        expect(targets(command)).to eq([expected])
      end
    end

    it 'reads a brace group, xargs -i and an empty find -exec' do
      expect(targets('{ git clean -f; }')).to eq([['/repo', %w[worktree], []]])
      expect(targets('xargs -i git branch -D {}')).to eq([['/repo', %w[branches], []]])
      expect(targets('find . -exec \\; && git clean -f')).to eq([['/repo', %w[worktree], []]])
      expect(targets('find . -exec git branch -D {} \\;')).to eq([['/repo', %w[branches], []]])
    end

    it 'skips shell comments, so an apostrophe in one hides nothing' do
      expect(targets("# Don't forget\ngit clean -f")).to eq([['/repo', %w[worktree], []]])
      expect(targets("git clean -f # don't")).to eq([['/repo', %w[worktree], []]])
      expect(targets("# git clean -f\nls")).to eq([])
      expect(targets('echo a#b; git clean -f')).to eq([['/repo', %w[worktree], []]])
    end

    it 'follows nested pushd and popd' do
      expect(targets('pushd /a; pushd /b; popd; git clean -f')).to eq([['/a', %w[worktree], []]])
    end

    it 'goes back to the directory Claude runs in after popd' do
      expect(targets('pushd /p; popd; git clean -f')).to eq([['/repo', %w[worktree], []]])
    end
  end

  describe 'the repository git uses' do
    {
      'git --work-tree=/other --git-dir=/other/.git reset --hard' => '/other',
      'git --git-dir /other/.git clean -f' => '/other',
      'GIT_DIR=/o/.git git clean -f' => '/o',
      'env GIT_DIR=/o/.git git clean -f' => '/o',
      'sudo GIT_WORK_TREE=/w git clean -f' => '/w',
      'GIT_WORK_TREE=/w GIT_DIR=/x/.git git clean -f' => '/w',
      'git -C /a --work-tree ../b clean -f' => '/b'
    }.each do |command, dir|
      it "snapshots #{dir} for `#{command}`" do
        expect(targets(command).map(&:first)).to eq([dir])
      end
    end
  end

  describe 'aliases' do
    subject(:parser) do
      described_class.new('/repo', aliases: lambda { |dir|
        dir == '/repo' ? aliases : {}
      })
    end

    let(:aliases) do
      { 'nuke' => 'reset --hard', 'wipe' => '!git clean -fd', 'st' => 'status', 'u' => 'nuke',
        'loop1' => 'loop2', 'loop2' => 'loop1' }
    end

    def scopes(command)
      targets(command).map { |target| target[1] }
    end

    it 'replaces an alias from -c or the configuration by what it stands for' do
      expect(scopes('git -c alias.x="reset --hard" x')).to eq([%w[branches head worktree]])
      expect(scopes('git nuke')).to eq([%w[branches head worktree]])
      expect(scopes('git wipe')).to eq([%w[worktree]])
      expect(scopes('git st')).to eq([])
    end

    it 'follows an alias of an alias, and stops on a loop' do
      expect(scopes('git u')).to eq([%w[branches head worktree]])
      expect(scopes('git loop1')).to eq([])
    end

    it 'never lets an alias replace a built-in command, as git does' do
      expect(targets('git -c alias.status="reset --hard" status')).to eq([])
    end
  end

  it 'finds commands after pipes and in subshells' do
    expect(targets('(cd x; git stash clear) | cat')).to eq([['/repo/x', %w[stashes], []]])
  end

  describe '#creations' do
    def creations(command)
      parser.creations(command).map { |creation| [creation[:dir], creation[:branch]] }
    end

    it 'finds the branch a command creates and the directory it runs in' do
      expect(creations('git checkout -b feat')).to eq([['/repo', 'feat']])
    end

    it 'follows cd and git -C' do
      expect(creations('cd /other && git switch -c a; git -C /third branch b'))
        .to eq([['/other', 'a'], ['/third', 'b']])
    end

    it 'finds every creation in a chain and ignores other commands' do
      expect(creations('git fetch && git checkout -b a && ls && git branch b main && git status'))
        .to eq([['/repo', 'a'], ['/repo', 'b']])
    end

    it 'finds nothing for commands that only use branches' do
      expect(creations('git checkout main && git branch -D old && echo checkout -b x')).to eq([])
    end
  end
end
