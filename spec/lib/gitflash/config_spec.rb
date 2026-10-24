# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Gitflash::Config do
  let(:dir) { Dir.mktmpdir('gitflash-config') }
  let(:root) { File.join(dir, 'proj') }
  let(:home) { File.join(dir, 'home') }
  let(:config) { described_class.load(root: root, home: home) }

  before { FileUtils.mkdir_p([root, File.join(home, '.config')]) }
  after { FileUtils.remove_entry(dir) }

  def write_repo(yaml) = File.write(File.join(root, '.gitflash.yml'), yaml)
  def write_user(yaml) = File.write(File.join(home, '.config', 'gitflash.yml'), yaml)

  it 'uses defaults when no file exists' do
    expect(config).to eq(described_class.defaults)
    expect(config.stale_days).to eq(30)
    expect(config.protected_patterns).to eq([])
  end

  it 'lets the repository file win over the user file, key by key' do
    write_user("stale_days: 60\nprotected: [release/*]\n")
    write_repo("stale_days: 7\n")
    expect(config.stale_days).to eq(7)
    expect(config.protected_patterns).to eq(['release/*'])
  end

  it 'adds the repository protected patterns to the user ones and never removes them' do
    write_user("protected: ['release/*', develop]\n")
    write_repo("protected: []\n")
    expect(config.protected_patterns).to eq(['release/*', 'develop'])

    write_repo("protected: [develop, hotfix/*]\n")
    reloaded = described_class.load(root: root, home: home)
    expect(reloaded.protected_patterns).to eq(['release/*', 'develop', 'hotfix/*'])
  end

  it 'matches protected patterns shell-style' do
    write_repo("protected: ['release/*', develop]\n")
    expect(config.protected?('release/1.0')).to be(true)
    expect(config.protected?('develop')).to be(true)
    expect(config.protected?('feature/x')).to be(false)
  end

  it 'protects nested branch names: * also matches across slashes' do
    write_repo("protected: ['release/*']\n")
    expect(config.protected?('release/1.0/rc')).to be(true)
  end

  it 'rejects a key given twice, so a protected list is never dropped silently' do
    write_repo("protected: [a]\nprotected: [b]\n")
    expect { config }.to raise_error(Gitflash::UsageError, /'protected' more than once/)
  end

  it 'loads a file whose keys are all different' do
    write_repo("protected: [a]\nstale_days: 5\n")
    expect(config.stale_days).to eq(5)
  end

  it 'reports a file that cannot be opened as invalid_config', unless: Process.uid.zero? do
    write_repo("stale_days: 5\n")
    File.chmod(0o000, File.join(root, '.gitflash.yml'))
    expect { config }.to raise_error(Gitflash::UsageError, /cannot be read/) { |e|
      expect(e.code).to eq('invalid_config')
    }
  end

  it 'builds the default worktree path next to the main checkout' do
    expect(config.worktree_path(root: root, branch: 'feat/a'))
      .to eq(File.expand_path('../proj.worktrees/feat/a', root))
  end

  it 'substitutes the placeholders as plain text, even when a branch name has a percent sign' do
    write_user("worktree_dir: /tmp/wt/%<repo>s/%<branch>s\n")
    expect(config.worktree_path(root: root, branch: '100%<branch>s'))
      .to eq('/tmp/wt/proj/100%<branch>s')
  end

  it 'adds snapshot_exclude from both files and matches paths and names' do
    write_user("snapshot_exclude: ['*.pem']\n")
    write_repo("snapshot_exclude: ['.env*']\n")
    expect(config.snapshot_exclude).to eq(['*.pem', '.env*'])
    expect(config.snapshot_excluded?('keys/id.pem')).to be(true)
    expect(config.snapshot_excluded?('app/.env.local')).to be(true)
    expect(config.snapshot_excluded?('README.md')).to be(false)
  end

  it 'honours a custom worktree_dir' do
    write_user("worktree_dir: /tmp/wt/%<branch>s\n")
    expect(config.worktree_path(root: root, branch: 'a')).to eq('/tmp/wt/a')
  end

  describe 'worktree_dir in the repository file' do
    it 'may place worktrees next to the main checkout' do
      write_repo("worktree_dir: ../wt-%<repo>s/%<branch>s\n")
      expect(config.worktree_path(root: root, branch: 'a')).to eq(File.join(dir, 'wt-proj', 'a'))
    end

    ['/tmp/wt/%<branch>s', '~/wt/%<branch>s', '~other/%<branch>s', '../../wt/%<branch>s',
     '../x/../../wt'].each do |template|
      it "may not point elsewhere: #{template}" do
        write_repo("worktree_dir: '#{template}'\n")
        expect { config }.to raise_error(Gitflash::UsageError, /'worktree_dir' must be a relative/)
      end
    end

    it 'may not lead out through a symbolic link in the repository' do
      outside = File.join(dir, 'outside')
      FileUtils.mkdir_p(outside)
      File.symlink(outside, File.join(root, 'wt-link'))
      write_repo("worktree_dir: wt-link/%<branch>s\n")
      expect { config.worktree_path(root: root, branch: 'a') }.not_to raise_error

      elsewhere = Dir.mktmpdir('gitflash-elsewhere')
      File.symlink(elsewhere, File.join(root, 'far-link'))
      write_repo("worktree_dir: far-link/%<branch>s\n")
      reloaded = described_class.load(root: root, home: home)
      expect { reloaded.worktree_path(root: root, branch: 'a') }
        .to raise_error(Gitflash::UsageError, /leads to .*outside/)
    ensure
      FileUtils.remove_entry(elsewhere) if elsewhere
    end

    it 'loses to the user file' do
      write_repo("worktree_dir: ../repo-wt/%<branch>s\n")
      write_user("worktree_dir: /tmp/mine/%<branch>s\n")
      expect(config.worktree_path(root: root, branch: 'a')).to eq('/tmp/mine/a')
    end
  end

  {
    "colour: red\n" => /unknown keys: colour/,
    "stale_days: soon\n" => /'stale_days' must be/,
    "stale_days: 0\n" => /'stale_days' must be/,
    "protected: main\n" => /'protected' must be/,
    "- a\n" => /must be a mapping/,
    "a: [\n" => /cannot be read/,
    "worktree_dir: '../%<repo>999999999s/x'\n" => /'worktree_dir' must be/,
    "worktree_dir: '../%d/%<branch>s'\n" => /'worktree_dir' must be/,
    "worktree_dir: '%%'\n" => /'worktree_dir' must be/,
    "worktree_dir: '#{'a' * 513}'\n" => /'worktree_dir' must be/
  }.each do |yaml, message|
    it "rejects #{yaml.inspect}" do
      write_repo(yaml)
      expect { config }.to raise_error(Gitflash::UsageError, message) { |e|
        expect(e.code).to eq('invalid_config')
      }
    end
  end
end
