# frozen_string_literal: true

require 'json'

module Gitflash
  module Hook
    # Claude Code hook for the Bash tool. PostToolUse input marks the branches the command
    # created as agent work (BranchMarker); everything below describes PreToolUse.
    #
    # Reads the hook input (JSON on stdin) and, when the command can lose work git cannot
    # restore, acts according to the mode:
    #   snapshot  save a snapshot and let the command run (default)
    #   ask       save a snapshot and ask the user to approve the command
    #   deny      block the command and point to the gitflash equivalent
    # Returns the hook output as a Hash, or nil to leave the decision to Claude Code.
    class Claude
      MODES = %w[snapshot ask deny].freeze
      EVENT = 'PreToolUse'
      POST_EVENT = 'PostToolUse'

      def initialize(mode: 'snapshot', snapshots: -> { Gitflash::Snapshots.new },
                     marker: BranchMarker.new)
        @mode = mode
        @snapshots = snapshots
        @marker = marker
      end

      def call(input)
        data = JSON.parse(input)
        return after_command(data) if data['hook_event_name'] == POST_EVENT

        before_command(data)
      end

      private

      # PreToolUse: remember which branches exist, then snapshot, ask or deny for risky commands
      def before_command(data)
        record_branches(data)
        targets = targets(data)
        return nil if targets.empty?
        return deny(targets) if @mode == 'deny'

        saved = merge_by_dir(targets).filter_map { |target| save(target) }
        # Asking is the user's protection: it must not depend on a snapshot having been saved
        saved.empty? && @mode != 'ask' ? nil : output(saved, targets)
      end

      # Recording is a side feature: when it fails, snapshots and the ask or deny decision still run
      def record_branches(data)
        return unless bash?(data)

        @marker.record(command_of(data), data['cwd'] || Dir.pwd, data['tool_use_id'])
      rescue StandardError => e
        warn "gitflash hook: could not record branches (#{e.message})"
      end

      # PostToolUse: mark the branches the command created, and tell Claude
      def after_command(data)
        return nil unless data['tool_name'] == 'Bash'

        marked = @marker.call(command_of(data), data['cwd'] || Dir.pwd, data['tool_use_id'])
        return nil if marked.empty?

        context = "gitflash marked #{marked.join(', ')} as agent work, so " \
                  '`gitflash clean --agent` can find it. Change it with ' \
                  '`gitflash mark BRANCH --owner human`.'
        { hookSpecificOutput: { hookEventName: POST_EVENT, additionalContext: context } }
      end

      def bash?(data)
        data['tool_name'] == 'Bash'
      end

      def command_of(data)
        data.dig('tool_input', 'command').to_s
      end

      def targets(data)
        return [] unless bash?(data)

        CommandParser.new(data['cwd'] || Dir.pwd).targets(command_of(data))
      end

      # One snapshot per directory, covering every command run there
      def merge_by_dir(targets)
        targets.group_by(&:dir).map do |dir, group|
          CommandParser::Target.new(
            dir: dir, command: group.map(&:command).join(' && '),
            scope: group.flat_map(&:scope).uniq, branches: group.flat_map(&:branches).uniq
          )
        end
      end

      # [target, snapshot], or nil when the directory is not a git work tree
      def save(target)
        return nil unless Dir.exist?(target.dir)

        Dir.chdir(target.dir) do
          next nil unless git('rev-parse', '--is-inside-work-tree') == 'true'

          snapshot = @snapshots.call.create(reason: "agent hook: before `#{target.command}`",
                                            scope: target.scope, branches: branches(target))
          [target, snapshot]
        end
      end

      # Full ref shortened by removing refs/heads/ only; `--short` changes when a tag has the name
      def current_branch
        git('symbolic-ref', '--quiet', 'HEAD')&.delete_prefix(Repo::HEADS)
      end

      def branches(target)
        target.branches.filter_map do |name|
          name == :current ? current_branch : name
        end
      end

      def output(saved, targets)
        context = saved.empty? ? Messages.unsaved(targets) : Messages.saved(saved)
        specific = { hookEventName: EVENT, additionalContext: context }
        if @mode == 'ask'
          specific[:permissionDecision] = 'ask'
          specific[:permissionDecisionReason] =
            "This command can discard work git cannot restore. #{context}"
        end
        { hookSpecificOutput: specific }
      end

      def deny(targets)
        { hookSpecificOutput: { hookEventName: EVENT, permissionDecision: 'deny',
                                permissionDecisionReason: Messages.denial(targets) } }
      end

      # Stripped stdout of a git command, or nil when it fails
      def git(*)
        stdout, _stderr, success = Git::BashCommand.capture('git', *)
        success ? stdout.strip : nil
      end
    end
  end
end
