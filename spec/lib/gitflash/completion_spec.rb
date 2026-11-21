# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe Gitflash::Completion, :git_repo do
  subject(:tree) { described_class.new }

  def available?(shell)
    system('sh', '-c', "command -v #{shell}", out: File::NULL, err: File::NULL)
  end

  # Runs the bash script's completion function for a command line whose last word is the one
  # being completed, inside the temporary repository, and returns the candidates
  def complete_bash(*words)
    Dir.mktmpdir do |dir|
      script = File.join(dir, 'gitflash.bash')
      File.write(script, tree.script('bash'))
      driver = <<~'SH'
        source "$1"; shift
        COMP_WORDS=("$@"); COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 )); COMPREPLY=()
        _gitflash
        printf '%s\n' "${COMPREPLY[@]}"
      SH
      stdout, status = Open3.capture2('bash', '-c', driver, 'bash', script, 'gitflash', *words)
      raise "bash failed: #{status}" unless status.success?

      stdout.split("\n")
    end
  end

  before do
    commit_file('a')
    git('branch', 'feature-one')
  end

  it 'lists top-level commands and groups, without Thor internals' do
    names = tree.children.map(&:first)
    expect([names & %w[branches worktree completion], names.include?('tree')])
      .to eq([%w[branches worktree completion], false])
  end

  it 'reads groups and their aliases from the CLI' do
    expect([tree.groups, tree.aliases]).to eq([%w[hook skill worktree], { 'wt' => 'worktree' }])
  end

  it 'leaves out hidden commands' do
    expect(tree.commands.map(&:path)).not_to include('hook claude')
  end

  it 'adds --no- for boolean options that default to true' do
    pick = tree.commands.find { |command| command.path == 'pick' }
    expect(pick.options.flat_map(&:switches)).to include('--commit', '--no-commit')
  end

  it 'refuses an unknown shell' do
    expect { tree.script('tcsh') }.to raise_error(ArgumentError, /tcsh/)
  end

  describe 'the scripts' do
    described_class::SHELLS.each do |shell|
      it "prints a #{shell} script that the shell parses" do
        skip "#{shell} is not installed" unless available?(shell)

        Dir.mktmpdir do |dir|
          path = File.join(dir, "gitflash.#{shell}")
          File.write(path, tree.script(shell))
          check = shell == 'fish' ? ['fish', '--no-execute', path] : [shell, '-n', path]
          expect(system(*check, err: File::NULL)).to be true
        end
      end
    end

    it 'names every top-level command in each script' do
      described_class::SHELLS.each do |shell|
        expect(tree.script(shell)).to include('branches', 'completion', 'worktree')
      end
    end
  end

  describe 'bash completion' do
    before { skip 'bash is not installed' unless available?('bash') }

    it 'completes commands' do
      expect(complete_bash('wo')).to eq(['worktree'])
    end

    it 'completes subcommands of an alias' do
      expect(complete_bash('wt', '')).to include('add', 'remove', 'list')
    end

    it 'completes branch names, skipping global options and their values' do
      expect(complete_bash('--confirm', 'TOKEN', 'delete', 'feat')).to eq(['feature-one'])
    end

    it 'completes the global and the command options' do
      expect(complete_bash('wt', 'add',
                           '--')).to include('--json', '--dry-run', '--from', '--owner')
    end

    it 'completes the values of an option of that command' do
      expect([complete_bash('mark', '--owner', ''),
              complete_bash('skill', 'install', '--scope', '')])
        .to eq([%w[agent human], %w[user project]])
    end

    it 'completes shell names for completion' do
      expect(complete_bash('completion', '')).to eq(%w[bash zsh fish])
    end
  end

  describe 'zsh and fish completion' do
    # fish completes a command line itself with `complete -C`; candidates are "word<TAB>text"
    def complete_fish(line)
      Dir.mktmpdir do |dir|
        script = File.join(dir, 'gitflash.fish')
        File.write(script, tree.script('fish'))
        stdout, status = Open3.capture2('fish', '--no-config', '-c',
                                        "source #{script}; complete -C '#{line}'")
        raise "fish failed: #{status}" unless status.success?

        stdout.split("\n").map { |candidate| candidate.split("\t").first }
      end
    end

    it 'completes subcommands, branches, options and values in fish' do
      skip 'fish is not installed' unless available?('fish')

      expect([complete_fish('gitflash wt re'), complete_fish('gitflash delete feat'),
              complete_fish('gitflash mark --owner '), complete_fish('gitflash wt add --fr')])
        .to eq([['remove'], ['feature-one'], %w[agent human], ['--from']])
    end
  end

  describe 'gitflash completion' do
    include CliHelper

    it 'prints the script' do
      expect(run_cli('completion', 'zsh').stdout).to start_with("#compdef gitflash\n")
    end

    it 'exits 2 for an unknown shell, in the JSON envelope with --json' do
      run = run_cli('completion', 'tcsh', '--json')
      expect([run.status, run.json.dig('error', 'code')]).to eq([2, 'invalid_usage'])
    end
  end
end
