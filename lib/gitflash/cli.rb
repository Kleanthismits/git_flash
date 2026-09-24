# frozen_string_literal: true

require 'thor'

module Gitflash
  class Cli < Thor
    extend Configuration::Descriptions

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
      run_command(Commands::Branches)
    end

    desc 'checkout [BRANCH]', descriptions.checkout.short
    long_desc descriptions.checkout.long
    def checkout(branch = nil)
      run_command(Commands::Checkout, *[branch].compact)
    end

    desc 'delete [BRANCH...]', descriptions.delete.short
    long_desc descriptions.delete.long
    option :force, type: :boolean, default: false,
                   desc: 'Delete branches even if they have unmerged changes'
    def delete(*branches)
      run_command(Commands::Delete, *branches)
    end

    desc 'reset [COMMIT]', descriptions.reset.short
    long_desc descriptions.reset.long
    option :hard, type: :boolean, default: false, desc: 'Discard all current changes'
    option :soft, type: :boolean, default: false, desc: 'Keep changes staged'
    def reset(commit = nil)
      run_command(Commands::Reset, *[commit].compact)
    end

    desc 'schema', 'Print the JSON Schema of the --json output'
    def schema
      puts File.read(SCHEMA_PATH)
    end

    desc 'version', 'Print the gitflash version'
    map %w[--version -v] => :version

    def version
      puts VERSION
    end

    private

    def run_command(command_class, *)
      ui = build_ui(command_class.name.split('::').last.downcase)
      repo = Repo.new
      repo.ensure_work_tree!
      status = command_class.new(repo: repo, ui: ui, options: options).call(*)
      exit(status) unless status.zero?
    rescue Error => e
      ui.error(e)
      exit(e.exit_code)
    end

    def build_ui(command)
      Ui.new(command: command, json: options[:json], yes: options[:yes], dry_run: options[:dry_run])
    end
  end
end
