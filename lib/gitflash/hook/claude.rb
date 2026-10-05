# frozen_string_literal: true

require 'json'

module Gitflash
  module Hook
    # Claude Code PreToolUse hook for the Bash tool.
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

      def initialize(mode: 'snapshot', snapshots: -> { Gitflash::Snapshots.new })
        @mode = mode
        @snapshots = snapshots
      end

      def call(input)
        targets = targets(JSON.parse(input))
        return nil if targets.empty?
        return deny(targets) if @mode == 'deny'

        saved = merge_by_dir(targets).filter_map { |target| save(target) }
        saved.empty? ? nil : output(saved)
      end

      private

      def targets(data)
        return [] unless data['tool_name'] == 'Bash'

        command = data.dig('tool_input', 'command').to_s
        CommandParser.new(data['cwd'] || Dir.pwd).targets(command)
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

      def output(saved)
        notes = saved.map { |target, snap| "snapshot #{snap.id} before `#{target.command}`" }
        context = "gitflash saved #{notes.join('; ')}. If this discards work that was still " \
                  "needed, restore it with `gitflash undo #{saved.last[1].id}` " \
                  '(list snapshots with `gitflash snapshots`).'
        specific = { hookEventName: EVENT, additionalContext: context }
        if @mode == 'ask'
          specific[:permissionDecision] = 'ask'
          specific[:permissionDecisionReason] =
            "This command can discard work git cannot restore. #{context}"
        end
        { hookSpecificOutput: specific }
      end

      def deny(targets)
        commands = targets.map { |target| "`#{target.command}`" }.join(', ')
        reason = "gitflash blocked #{commands}: it can discard work git cannot restore. " \
                 'Use the gitflash equivalent (gitflash reset, gitflash delete, ...), which ' \
                 'saves a snapshot first, or run `gitflash snapshot` before retrying.'
        { hookSpecificOutput: { hookEventName: EVENT, permissionDecision: 'deny',
                                permissionDecisionReason: reason } }
      end

      # Stripped stdout of a git command, or nil when it fails
      def git(*)
        stdout, _stderr, success = Git::BashCommand.capture('git', *)
        success ? stdout.strip : nil
      end
    end
  end
end
