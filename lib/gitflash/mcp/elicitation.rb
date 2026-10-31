# frozen_string_literal: true

require 'json'
require 'timeout'

module Gitflash
  module Mcp
    # Asks the user to approve a destructive tool's plan through the MCP client (a form with one
    # checkbox), when the client declared the `elicitation` capability. The answer comes from the
    # user, not the agent, so an approved plan runs without a second call. Whenever the user
    # cannot be asked (no capability, an error, no answer within TIMEOUT seconds; some clients
    # never answer), `ask` returns nil and the tool falls back to the confirm_token flow.
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

      def initialize(enabled: true, timeout: TIMEOUT)
        @enabled = enabled
        @timeout = timeout
      end

      # :accepted, :declined, or nil when the user could not be asked
      def ask(context, tool, plan)
        return unless @enabled && context&.client_capabilities&.dig(:elicitation)

        answer = Timeout.timeout(@timeout) do
          context.create_form_elicitation(message: message(tool, plan), requested_schema: SCHEMA)
        end
        decision(answer)
      rescue StandardError
        nil
      end

      private

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
