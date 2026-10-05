# frozen_string_literal: true

module Gitflash
  # Runs a command class with the parsed Thor options and turns errors into output and exit codes
  module CommandRunner
    private

    def run_command(name, command_class, *, repo_required: true)
      ui = build_ui(name)
      repo = Repo.new
      repo.ensure_work_tree! if repo_required
      status = command_class.new(repo: repo, ui: ui, options: options).call(*)
      exit(status) unless status.zero?
    rescue Error => e
      ui.error(e)
      exit(e.exit_code)
    end

    def build_ui(name)
      Ui.new(command: name, json: options[:json], yes: options[:yes], dry_run: options[:dry_run])
    end
  end
end
