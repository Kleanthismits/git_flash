# frozen_string_literal: true

require 'thor'

module Gitflash
  class Cli < Thor
    extend Configuration::Descriptions
    include CommandRunner

    SCHEMA_PATH = File.expand_path('../../schema/v1.json', __dir__)

    def self.exit_on_failure?
      true
    end

    class_option :json, type: :boolean, default: false,
                        desc: 'Print JSON instead of text; never prompts'
    class_option :yes, type: :boolean, aliases: '-y', default: false,
                       desc: 'Skip confirmation prompts'
    class_option :dry_run, type: :boolean, default: false,
                           desc: 'Show what would happen without changing anything'

    desc 'branches', descriptions.branches.short
    long_desc descriptions.branches.long
    option :merged, type: :boolean, desc: 'Branches merged into the default branch'
    option :gone, type: :boolean, desc: 'Branches whose upstream branch was deleted'
    option :stale, type: :numeric, banner: 'DAYS', desc: 'Branches without commits for DAYS days'
    def branches
      run_command('branches', Commands::Branches)
    end

    desc 'checkout [BRANCH]', descriptions.checkout.short
    long_desc descriptions.checkout.long
    def checkout(branch = nil)
      run_command('checkout', Commands::Checkout, *[branch].compact)
    end

    desc 'delete [BRANCH...]', descriptions.delete.short
    long_desc descriptions.delete.long
    option :force, type: :boolean, default: false,
                   desc: 'Delete branches even if they have unmerged changes'
    def delete(*branches)
      run_command('delete', Commands::Delete, *branches)
    end

    desc 'clean', descriptions.clean.short
    long_desc descriptions.clean.long
    option :merged, type: :boolean, desc: 'Branches merged into the default branch'
    option :gone, type: :boolean, desc: 'Branches whose upstream branch was deleted'
    option :stale, type: :string, banner: 'DAYS', lazy_default: '',
                   desc: 'Branches without commits for DAYS days (default: stale_days setting)'
    option :agent, type: :boolean, desc: 'Branches created by an agent'
    option :force, type: :boolean, default: false,
                   desc: 'Also delete selected branches that have unmerged changes'
    def clean
      run_command('clean', Commands::Clean)
    end

    desc 'reset [COMMIT]', descriptions.reset.short
    long_desc descriptions.reset.long
    option :hard, type: :boolean, default: false, desc: 'Discard all current changes'
    option :soft, type: :boolean, default: false, desc: 'Keep changes staged'
    def reset(commit = nil)
      run_command('reset', Commands::Reset, *[commit].compact)
    end

    desc 'undo [SNAPSHOT]', descriptions.undo.short
    long_desc descriptions.undo.long
    def undo(snapshot = nil)
      run_command('undo', Commands::Undo, *[snapshot].compact)
    end

    desc 'snapshots', 'List snapshots, newest first'
    def snapshots
      run_command('snapshots', Commands::SnapshotList)
    end

    desc 'snapshot', descriptions.snapshot.short
    long_desc descriptions.snapshot.long
    option :message, type: :string, desc: 'Why the snapshot was taken'
    option :scope, type: :array, banner: 'PARTS',
                   desc: 'Parts to save: branches head worktree stashes (default: all)'
    def snapshot
      run_command('snapshot', Commands::SnapshotCreate)
    end

    desc 'gc', 'Delete old snapshots'
    option :older_than, type: :numeric, banner: 'DAYS',
                        desc: 'Delete snapshots older than DAYS days (default 30)'
    def gc
      run_command('gc', Commands::Gc)
    end

    desc 'hook SUBCOMMAND', 'Agent hooks: claude (run the hook), install (register it)'
    subcommand 'hook', HookCli

    desc 'worktree SUBCOMMAND', 'Worktrees for parallel agent work (alias: wt)'
    subcommand 'worktree', WorktreeCli
    map 'wt' => :worktree

    desc 'schema', 'Print the JSON Schema of the --json output'
    def schema
      puts File.read(SCHEMA_PATH)
    end

    desc 'version', 'Print the gitflash version'
    map %w[--version -v] => :version

    def version
      puts VERSION
    end
  end
end
