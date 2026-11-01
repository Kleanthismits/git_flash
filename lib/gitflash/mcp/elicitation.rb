# frozen_string_literal: true

require 'json'
require 'mcp'
require 'timeout'

module Gitflash
  module Mcp
    # Asks the user to approve a destructive tool's plan through the MCP client (a form with one
    # checkbox), when the client declared the `elicitation` capability. The answer comes from the
    # user, not the agent, so an approved plan runs without a second call.
    #
    # How depends on the connection. A legacy one (`initialize`) sends `elicitation/create` and
    # waits up to TIMEOUT seconds; some clients never answer. The 2026-07-28 lifecycle forbids
    # requests from the server, so there `ask` returns an `input_required` result holding the
    # form, and the client calls the tool again with the answer (`answer`) and the state.
    #
    # Whenever the user cannot be asked, `ask` returns nil and the tool falls back to the
    # confirm_token flow, and the reason goes to stderr.
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
      FORM = 'confirm'

      LOG = ->(text) { warn "gitflash mcp: #{text}" }

      def initialize(enabled: true, timeout: TIMEOUT, log: LOG)
        @enabled = enabled
        @timeout = timeout
        @log = log
      end

      # :accepted, :declined, an `input_required` result (2026-07-28 lifecycle), or nil when the
      # user cannot be asked. `state` gives the request state the client echoes on its retry.
      # Without a request context (a call from Ruby, not from a client) there is nobody to ask
      # and nothing is logged.
      def ask(context, tool, plan, state:)
        return unless context

        reason = unavailable(context)
        return skipped(tool, reason) if reason
        return form(context, tool, plan, state.call) if context.modern?

        direct(context, tool, plan)
      end

      # The user's answer on the retry of an `input_required` round. `fits` says whether the state
      # the client echoed still confirms the plan the repository gives now.
      def answer(context, tool, fits:)
        return skipped(tool, 'the plan changed or the form expired') unless fits

        response = context.input_response(FORM)
        decision(response) || skipped(tool, "unknown answer #{response.inspect[0, 200]}")
      end

      private

      def direct(context, tool, plan)
        answer = Timeout.timeout(@timeout) do
          context.create_form_elicitation(message: message(tool, plan), requested_schema: SCHEMA)
        end
        decision(answer) || skipped(tool, "unknown answer #{answer.inspect[0, 200]}")
      rescue Timeout::Error
        skipped(tool, "no answer within #{@timeout} seconds")
      rescue StandardError => e
        skipped(tool, "asking failed: #{e.class}: #{e.message}")
      end

      def form(context, tool, plan, state)
        params = { mode: 'form', message: message(tool, plan), requestedSchema: SCHEMA }
        result = MCP::Server::InputRequiredResult.new(
          input_requests: { FORM => { method: 'elicitation/create', params: params } },
          request_state: state
        )
        missing = result.missing_client_capabilities(context.client_capabilities)
        missing.empty? ? result : skipped(tool, "the client cannot show forms (#{missing.to_json})")
      end

      def unavailable(context)
        return 'started with --no-elicitation' unless @enabled

        capabilities = context.client_capabilities
        return if capabilities.is_a?(Hash) && (capabilities.key?(:elicitation) ||
                                               capabilities.key?('elicitation'))

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
