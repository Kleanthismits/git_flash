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

    TERMINAL_NOTE = 'gitflash hook claude is run by Claude Code, not by hand. Use ' \
                    '`gitflash hook install` to set it up and `gitflash hook status` to check it.'

    desc 'claude',
         'Run as a Claude Code hook (PreToolUse and PostToolUse; reads the input on stdin)',
         hide: true
    long_desc <<~TEXT
      Reads the Claude Code hook input on stdin. When the Bash command can discard work git
      cannot restore (for example reset --hard, clean -f, checkout -- ., branch -D, stash drop),
      it saves a snapshot first and tells Claude how to undo it.

      --mode snapshot  save a snapshot and let the command run (default)
      --mode ask       save a snapshot and ask the user to approve the command
      --mode deny      block the command and point to the gitflash equivalent

      As a PostToolUse hook it marks the branches the command created (git checkout -b, switch -c,
      branch NAME, worktree add) as agent work, so `gitflash clean --agent` can find them. A branch
      is only marked when it is new (its reflog says it was created a moment ago) and unmarked.

      Not meant to be run by hand: in a terminal it only prints a note. Errors are printed to
      stderr and the hook exits with 0. In snapshot mode the command then runs; in ask mode the
      user is asked and in deny mode the command is blocked, so an error never turns the
      protection off. If even that answer cannot be written, ask and deny mode exit with 2,
      which makes Claude Code block the command.
    TEXT
    option :mode, type: :string, default: 'snapshot', enum: Hook::Claude::MODES
    def claude
      return puts(TERMINAL_NOTE) if $stdin.tty?

      output = hook_output(options[:mode], $stdin.read)
      puts JSON.generate(output) if output
    rescue StandardError => e
      warn "gitflash hook: #{e.message}"
      # No decision could be written: exit 2 makes Claude Code block the command in ask and
      # deny mode instead of running it unprotected
      exit 2 unless options[:mode] == 'snapshot'
    end

    no_commands do
      # The hook's output; on an error, what Hook::Failure decides for the mode
      def hook_output(mode, input)
        Hook::Claude.new(mode: mode).call(input)
      rescue StandardError => e
        warn "gitflash hook: #{e.message}"
        Hook::Failure.output(mode, e, input)
      end
    end

    desc 'install', 'Register the gitflash hook in Claude Code settings'
    long_desc <<~TEXT
      Adds `gitflash hook claude` as a PreToolUse hook (snapshots before destructive commands) and
      as a PostToolUse hook (marks branches an agent creates) for Bash commands. Keeps the rest of
      the settings file unchanged and does nothing when both are already installed. Run it again
      to add the PostToolUse hook to an older install.

      --scope local    .claude/settings.local.json at the repository root (default, not
                       committed); applies to sessions anywhere in the repository and its worktrees
      --scope project  .claude/settings.json at the repository top level (shared with the team);
                       applies to sessions started there
      --scope user     ~/.claude/settings.json; applies to every session

      Claude Code reloads settings files, so running sessions pick the hook up without a restart.
      Check the result with `gitflash hook status`.

      Accepts the global --json and --dry-run options after the subcommand: gitflash hook install --json
    TEXT
    option :scope, type: :string, default: 'local', enum: Commands::HookInstall::SCOPES
    option :mode, type: :string, default: 'snapshot', enum: Hook::Claude::MODES
    def install
      run_command('hook install', Commands::HookInstall, repo_required: options[:scope] != 'user')
    end

    desc 'status', 'Show whether the gitflash hook protects Claude Code sessions here'
    long_desc <<~TEXT
      Lists the Claude Code settings files that apply to the current directory, whether each
      holds the gitflash hooks (and whether branch marking is on) and which sessions it applies to,
      and whether the gitflash
      executable the hook runs is on PATH. Works outside a git repository (user scope only).
    TEXT
    def status
      run_command('hook status', Commands::HookStatus, repo_required: false)
    end
  end
end
