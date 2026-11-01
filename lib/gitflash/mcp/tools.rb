# frozen_string_literal: true

require 'json'

module Gitflash
  module Mcp
    # The tools `gitflash mcp` offers. Each one is a gitflash command; `argv` turns the tool's
    # arguments into that command's words. The kind decides how it runs (see Server):
    #   read         reads only
    #   additive     changes the repository in a way that loses nothing; runs at once
    #   destructive  can discard work; the first call returns the plan and a confirm_token,
    #                a second call with the token makes the change. A snapshot is always
    #                saved first, so `undo` can bring it back.
    #   plan         plan_change: the plan and token of a destructive tool, as a read-only tool,
    #                so a client that asks before every destructive call asks only once
    module Tools
      Tool = Data.define(:name, :kind, :description, :properties, :required, :argv)

      # Names, SHAs and paths become command words, so one that starts with a dash could turn
      # into an option
      NAME = { type: 'string', minLength: 1, pattern: '^[^-]' }.freeze
      NAMES = { type: 'array', items: NAME, minItems: 1 }.freeze
      DAYS = { type: 'integer', minimum: 1 }.freeze

      # --merged, --gone, --stale DAYS, ... from the boolean and number arguments that are set
      def self.flags(args, *names)
        names.flat_map do |name|
          value = args[name]
          flag = "--#{name.to_s.delete_suffix('_days').tr('_', '-')}"
          if value.is_a?(Integer) then [flag, value.to_s]
          elsif value == true then [flag]
          else []
          end
        end
      end

      FILTERS = {
        merged: { type: 'boolean', description: 'Branches merged into the default branch' },
        gone: { type: 'boolean', description: 'Branches whose upstream branch was deleted' },
        stale_days: DAYS.merge(description: 'Branches without commits for this many days')
      }.freeze

      COMMANDS = [
        Tool.new(
          name: 'list_branches', kind: :read,
          description: 'List local branches with last commit, upstream (ahead, behind, gone), ' \
                       'merge status and owner (agent or human). A branch is listed when it ' \
                       'matches any filter given.',
          properties: FILTERS, required: [],
          argv: ->(a) { ['branches', *flags(a, :merged, :gone, :stale_days)] }
        ),
        Tool.new(
          name: 'list_worktrees', kind: :read,
          description: 'List worktrees with absolute path, branch, HEAD, dirty state, ' \
                       'ahead/behind, merge status, lock state and owner.',
          properties: {}, required: [], argv: ->(_) { %w[worktree list] }
        ),
        Tool.new(
          name: 'list_pickable_commits', kind: :read,
          description: 'List the commits of a source branch that are not on the current branch ' \
                       'yet. Commits whose patch is already here are marked.',
          properties: { source: NAME.merge(description: 'Branch to pick from') },
          required: %w[source], argv: ->(a) { ['pick', a[:source], '--list'] }
        ),
        Tool.new(
          name: 'list_snapshots', kind: :read,
          description: 'List the snapshots gitflash saved before changes, newest first.',
          properties: {}, required: [], argv: ->(_) { %w[snapshots] }
        ),
        Tool.new(
          name: 'add_worktree', kind: :additive,
          description: 'Add a worktree for a branch: an existing local branch, a branch that ' \
                       'only exists on origin, or a new branch (from HEAD or `from`). New ' \
                       'branches are marked as agent work. The result holds the absolute path.',
          properties: { branch: NAME, from: NAME.merge(description: 'Start a new branch here'),
                        path: NAME.merge(description: 'Directory (default from worktree_dir)') },
          required: %w[branch],
          argv: lambda { |a|
            ['worktree', 'add', a[:branch], *(a[:from] ? ['--from', a[:from]] : []),
             *(a[:path] ? ['--path', a[:path]] : [])]
          }
        ),
        Tool.new(
          name: 'cherry_pick_commits', kind: :additive,
          description: 'Apply commits of a source branch to the current branch, oldest first, ' \
                       'with `git cherry-pick -x`, after a snapshot. On a conflict it stops with ' \
                       'error code `conflict` and lists the files; then use cherry_pick_control.',
          properties: { source: NAME, shas: NAMES,
                        commit: { type: 'boolean',
                                  description: 'false only stages the changes (default true)' } },
          required: %w[source shas],
          argv: lambda { |a|
            ['pick', a[:source], *a[:shas], '--yes', *(a[:commit] == false ? ['--no-commit'] : [])]
          }
        ),
        Tool.new(
          name: 'cherry_pick_control', kind: :additive,
          description: 'Continue a stopped pick after resolving its conflicts, skip the commit ' \
                       'that conflicts, or abort and return to the state before the pick.',
          properties: { action: { enum: %w[continue skip abort] } }, required: %w[action],
          argv: ->(a) { ['pick', "--#{a[:action]}", '--yes'] }
        ),
        Tool.new(
          name: 'mark_branches', kind: :additive,
          description: 'Mark branches as agent or human work (or clear the mark), so ' \
                       'clean_branches with `agent` can find agent branches.',
          properties: { branches: NAMES, owner: { enum: Ownership::OWNERS },
                        clear: { type: 'boolean' } },
          required: %w[branches],
          argv: lambda { |a|
            ['mark', *a[:branches], *(a[:clear] ? ['--clear'] : ['--owner', a[:owner] || 'agent'])]
          }
        ),
        Tool.new(
          name: 'save_snapshot', kind: :additive,
          description: 'Save the current branches, HEAD, files and stashes, so undo can come ' \
                       'back here.',
          properties: { message: { type: 'string', description: 'Why the snapshot is taken' } },
          required: [],
          argv: ->(a) { ['snapshot', *(a[:message] ? ['--message', a[:message]] : [])] }
        ),
        Tool.new(
          name: 'delete_branches', kind: :destructive,
          description: 'Delete local branches. Protected branches are never deleted; unmerged ' \
                       'ones only with `force`.',
          properties: { branches: NAMES, force: { type: 'boolean' } }, required: %w[branches],
          argv: ->(a) { ['delete', *a[:branches], *flags(a, :force)] }
        ),
        Tool.new(
          name: 'clean_branches', kind: :destructive,
          description: 'Delete merged branches and branches whose upstream is gone, and with ' \
                       '`stale_days` or `agent` also stale or agent-created ones. Unmerged ones ' \
                       'only with `force`. Protected branches are never deleted.',
          properties: FILTERS.merge(agent: { type: 'boolean', description: 'Agent branches' },
                                    force: { type: 'boolean' }),
          required: [],
          argv: ->(a) { ['clean', *flags(a, :merged, :gone, :stale_days, :agent, :force)] }
        ),
        Tool.new(
          name: 'reset_branch', kind: :destructive,
          description: 'Reset the current branch to a commit: mixed (default) keeps changes ' \
                       'unstaged, soft keeps them staged, hard discards them.',
          properties: { commit: NAME, mode: { enum: %w[mixed soft hard] } }, required: %w[commit],
          argv: lambda { |a|
            ['reset', a[:commit], *(%w[soft hard].include?(a[:mode]) ? ["--#{a[:mode]}"] : [])]
          }
        ),
        Tool.new(
          name: 'remove_worktrees', kind: :destructive,
          description: 'Remove worktrees, given as paths or branch names. Dirty or locked ones ' \
                       'only with `force`. Ignored files in them are deleted and no snapshot ' \
                       'saves them: the plan lists them.',
          properties: { worktrees: NAMES, force: { type: 'boolean' } }, required: %w[worktrees],
          argv: ->(a) { ['worktree', 'remove', *a[:worktrees], *flags(a, :force)] }
        ),
        Tool.new(
          name: 'move_worktree', kind: :destructive,
          description: 'Move a worktree (path or branch name) to another directory.',
          properties: { worktree: NAME, path: NAME, force: { type: 'boolean' } },
          required: %w[worktree path],
          argv: ->(a) { ['worktree', 'move', a[:worktree], a[:path], *flags(a, :force)] }
        ),
        Tool.new(
          name: 'undo', kind: :destructive,
          description: 'Restore a snapshot: by default the latest one taken in this worktree. ' \
                       'The current state is saved first, so an undo can be undone.',
          properties: { snapshot: NAME.merge(description: 'Snapshot id from a result or ' \
                                                          'list_snapshots') },
          required: [], argv: ->(a) { ['undo', *[a[:snapshot]].compact] }
        )
      ].freeze

      PLAN = Tool.new(
        name: 'plan_change', kind: :plan,
        description: 'Show what a destructive tool would do, without changing anything: returns ' \
                     'its plan with status confirmation_required and error.confirm_token. Then ' \
                     'call that tool with the same arguments and confirm_token to make the change.',
        properties: {
          tool: { enum: COMMANDS.select { |tool| tool.kind == :destructive }.map(&:name) },
          arguments: { type: 'object', description: "The destructive tool's arguments" }
        },
        required: %w[tool arguments], argv: nil
      )

      ALL = [*COMMANDS, PLAN].freeze

      # The JSON Schema of a tool's arguments, with string keys
      def self.input_schema(tool)
        JSON.parse(JSON.generate({ type: 'object', properties: tool.properties,
                                   required: tool.required, additionalProperties: false }))
      end
    end
  end
end
