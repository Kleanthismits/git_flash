# frozen_string_literal: true

require 'json'
require 'thor'

module Gitflash
  # `gitflash hook ...`: integrations that let agents keep using plain git safely
  class HookCli < Thor
    include CommandRunner

    namespace 'hook'

    def self.exit_on_failure?
      true
    end

    desc 'claude', 'Run as a Claude Code PreToolUse hook (reads the hook input on stdin)'
    long_desc <<~TEXT
      Reads the Claude Code hook input on stdin. When the Bash command can discard work git
      cannot restore (for example reset --hard, clean -f, checkout -- ., branch -D, stash drop),
      it saves a snapshot first and tells Claude how to undo it.

      --mode snapshot  save a snapshot and let the command run (default)
      --mode ask       save a snapshot and ask the user to approve the command
      --mode deny      block the command and point to the gitflash equivalent

      Errors never block the command: they are printed to stderr and the hook exits with 0.
    TEXT
    option :mode, type: :string, default: 'snapshot', enum: Hook::Claude::MODES
    def claude
      output = Hook::Claude.new(mode: options[:mode]).call($stdin.read)
      puts JSON.generate(output) if output
    rescue StandardError => e
      warn "gitflash hook: #{e.message}"
    end

    desc 'install', 'Register the gitflash hook in Claude Code settings'
    long_desc <<~TEXT
      Adds `gitflash hook claude` as a PreToolUse hook for Bash commands. Keeps the rest of the
      settings file unchanged and does nothing when the hook is already installed.

      --scope local    .claude/settings.local.json at the repository root (default, not
                       committed); applies to sessions anywhere in the repository and its worktrees
      --scope project  .claude/settings.json at the repository top level (shared with the team);
                       applies to sessions started there
      --scope user     ~/.claude/settings.json; applies to every session

      Claude Code reloads settings files, so running sessions pick the hook up without a restart.
      Check the result with `gitflash hook status`.

      Accepts the global --json and --dry-run options: gitflash --json hook install
    TEXT
    option :scope, type: :string, default: 'local', enum: Commands::HookInstall::SCOPES
    option :mode, type: :string, default: 'snapshot', enum: Hook::Claude::MODES
    def install
      run_command('hook install', Commands::HookInstall, repo_required: options[:scope] != 'user')
    end

    desc 'status', 'Show whether the gitflash hook protects Claude Code sessions here'
    long_desc <<~TEXT
      Lists the Claude Code settings files that apply to the current directory, whether each
      holds the gitflash hook and which sessions it applies to, and whether the gitflash
      executable the hook runs is on PATH. Works outside a git repository (user scope only).
    TEXT
    def status
      run_command('hook status', Commands::HookStatus, repo_required: false)
    end
  end
end
