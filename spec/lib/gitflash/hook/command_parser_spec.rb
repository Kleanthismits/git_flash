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
    'eval "git branch -D old"' => [['/repo', %w[branches], %w[old]]]
  }.each do |command, expected|
    it "reports `#{command}`" do
      expect(targets(command)).to eq(expected)
    end
  end

  [
    'git status', 'git commit -m "wip"', 'git checkout main', 'git clean -n', 'git clean -fn',
    'git stash', 'git branch new', 'git rebase --continue', 'git push --force', 'ls -la',
    'git worktree remove ../wt', 'echo "git reset --hard"'
  ].each do |command|
    it "ignores `#{command}`" do
      expect(targets(command)).to eq([])
    end
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
