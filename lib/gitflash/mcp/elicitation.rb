# frozen_string_literal: true

require 'json'
require 'timeout'

module Gitflash
  module Mcp
    # Asks the user to approve a destructive tool's plan through the MCP client (a form with one
    # checkbox), when the client declared the `elicitation` capability. The answer comes from the
    # user, not the agent, so an approved plan runs without a second call. Whenever the user
    # cannot be asked (no capability, an error, no answer within TIMEOUT seconds; some clients
    # never answer), `ask` returns nil and the tool falls back to the confirm_token flow, and the
    # reason goes to stderr, which MCP clients keep in their server logs.
    class Elicitation
      TIMEOUT = 120
      SCHEMA = {
        type: 'object',
        properties: {
          confirm: { type: 'boolean', title: 'Make this change',
                     description: 'gitflash saves a snapshot first' }
        },
        required: %w[confirm]
      }.freeze
      MAX_MESSAGE = 4000

      LOG = ->(text) { warn "gitflash mcp: #{text}" }

      def initialize(enabled: true, timeout: TIMEOUT, log: LOG)
        @enabled = enabled
        @timeout = timeout
        @log = log
      end

      # :accepted, :declined, or nil when the user could not be asked. Without a request context
      # (a call from Ruby, not from a client) there is nobody to ask and nothing is logged.
      def ask(context, tool, plan)
        return unless context

        reason = unavailable(context)
        return skipped(tool, reason) if reason

        answer = Timeout.timeout(@timeout) do
          context.create_form_elicitation(message: message(tool, plan), requested_schema: SCHEMA)
        end
        decision(answer) || skipped(tool, "unknown answer #{answer.inspect[0, 200]}")
      rescue Timeout::Error
        skipped(tool, "no answer within #{@timeout} seconds")
      rescue StandardError => e
        skipped(tool, "asking failed: #{e.class}: #{e.message}")
      end

      private

      def unavailable(context)
        return 'started with --no-elicitation' unless @enabled

        capabilities = context.client_capabilities
        return if capabilities.is_a?(Hash) && capabilities.key?(:elicitation)

        "the client did not declare the elicitation capability (#{capabilities.inspect[0, 200]})"
      end

      def skipped(tool, reason)
        @log.call("#{tool.name}: not asking the user, #{reason}; using the confirm_token")
        nil
      end

      # Accepting the form without ticking the box is a no, as are decline and cancel
      def decision(answer)
        answer = JSON.parse(JSON.generate(answer))
        return unless answer.is_a?(Hash) && %w[accept decline cancel].include?(answer['action'])

        approved = answer['action'] == 'accept' && answer.dig('content', 'confirm') == true
        approved ? :accepted : :declined
      end

      # Branch names, paths and commit subjects come from the repository, so control characters
      # are shown as escapes and cannot rewrite what the user reads
      def message(tool, plan)
        text = "gitflash #{tool.name} plans this change. A snapshot is saved first; the plan " \
               "lists anything gitflash undo cannot bring back.\n\n" \
               "#{TerminalText.safe(JSON.pretty_generate(plan))}"
        text.length > MAX_MESSAGE ? "#{text[0, MAX_MESSAGE]}\n..." : text
      end
    end
  end
end
