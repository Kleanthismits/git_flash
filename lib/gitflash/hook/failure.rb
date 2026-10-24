# frozen_string_literal: true

require 'json'

module Gitflash
  module Hook
    # What the PreToolUse hook outputs when it fails: in ask and deny mode the command is asked
    # about or blocked, because letting it run would turn the user's protection off; in snapshot
    # mode it runs, as it would without the hook. PostToolUse runs after the command, so there is
    # nothing left to decide.
    module Failure
      module_function

      # The hook output as a Hash, or nil to leave the decision to Claude Code
      def output(mode, error, input)
        return nil if mode == 'snapshot' || post_event?(input)

        { hookSpecificOutput: { hookEventName: Claude::EVENT, permissionDecision: mode,
                                permissionDecisionReason: Messages.failure(error) } }
      end

      def post_event?(input)
        JSON.parse(input)['hook_event_name'] == Claude::POST_EVENT
      rescue StandardError
        false
      end
    end
  end
end
