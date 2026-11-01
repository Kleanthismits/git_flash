# frozen_string_literal: true

require 'json'
require 'mcp'

module Gitflash
  module Mcp
    # `gitflash mcp`: an MCP server on stdio for the repository in its working directory.
    # Every tool runs a gitflash command (Runner) and answers with its JSON v1 envelope, so the
    # tools and the CLI share one contract. A destructive tool first asks the user to approve its
    # plan through the client (Elicitation). When the client cannot ask, it takes two calls: the
    # first returns the plan with status `confirmation_required` and `error.confirm_token`, the
    # second passes that token as `confirm_token` and makes exactly that change (Confirmation).
    class Server
      INSTRUCTIONS = <<~TEXT
        gitflash works on the git repository this server was started in. Every result is the
        gitflash JSON envelope (`gitflash schema` describes it): check `ok`, `status` and
        `error.code`. Changes save a snapshot first; keep `undo.command` and tell the user how to
        undo. To see what a destructive tool would do, call plan_change (read-only); it returns
        the plan and a confirm_token. Destructive tools ask the user to approve the plan when
        the client supports
        elicitation, unless called with a confirm_token; status `cancelled` means the user
        declined, so do not retry. Otherwise they answer the first call with the plan, status
        `confirmation_required` and `error.confirm_token`: show the plan to the user, and only
        when it is what they asked for, call the tool again with the same arguments and
        `confirm_token`. A token expires after 5 minutes and only confirms that plan.
      TEXT

      ANNOTATIONS = {
        read: { read_only_hint: true, destructive_hint: false, idempotent_hint: true },
        additive: { read_only_hint: false, destructive_hint: false, idempotent_hint: false },
        destructive: { read_only_hint: false, destructive_hint: true, idempotent_hint: false },
        plan: { read_only_hint: true, destructive_hint: false, idempotent_hint: false }
      }.freeze

      CONFIRM_TOKEN = { type: 'string',
                        description: 'The error.confirm_token of plan_change or of the first ' \
                                     'call, to make the change it planned' }.freeze

      def initialize(runner: Runner.new, confirmation: Confirmation.new,
                     elicitation: Elicitation.new)
        @runner = runner
        @confirmation = confirmation
        @elicitation = elicitation
      end

      def start
        MCP::Server::Transports::StdioTransport.new(mcp_server).open
      end

      def mcp_server
        MCP::Server.new(name: 'gitflash', version: VERSION, instructions: INSTRUCTIONS,
                        tools: Tools::ALL.map { |tool| mcp_tool(tool) })
      end

      # The envelope a tool answers with. `context` is the MCP server context of the request,
      # through which the user can be asked.
      def call(tool, arguments, context = nil)
        arguments = arguments.transform_keys(&:to_sym)
        return destructive(tool, arguments, context) if tool.kind == :destructive
        return PlanChange.new(@runner, @confirmation).call(arguments) if tool.kind == :plan

        @runner.call(tool.argv.call(arguments))
      end

      private

      def mcp_tool(tool)
        server = self
        schema = Tools.input_schema(tool)
        schema['properties']['confirm_token'] = CONFIRM_TOKEN if tool.kind == :destructive
        MCP::Tool.define(
          name: tool.name, description: tool.description, input_schema: schema,
          annotations: ANNOTATIONS.fetch(tool.kind).merge(open_world_hint: false)
        ) do |server_context: nil, **arguments|
          result = server.call(tool, arguments, server_context)
          result.is_a?(Hash) ? server.send(:respond, result) : result
        end
      end

      def respond(envelope)
        MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(envelope) }],
                                structured_content: envelope,
                                error: %w[error failed].include?(envelope['status']))
      end

      # The dry run gives the plan. A valid token for it, or the user's approval, makes the
      # change; a declined plan is cancelled; otherwise the plan is returned with a new token.
      # Nothing to do or an error is returned as it is.
      def destructive(tool, arguments, context)
        token = arguments.delete(:confirm_token)
        arguments = arguments.sort.to_h
        argv = tool.argv.call(arguments)
        preview = @runner.call([*argv, '--dry-run'])
        return preview unless preview['status'] == 'planned'

        plan = preview['plan']
        return run(argv, plan) if token && @confirmation.valid?(token, tool.name, arguments, plan)

        approve(tool, arguments, preview, token, context)
      end

      # A token that does not fit gets a new one without asking: the agent asked for this change
      # before, so the user is not asked twice
      def approve(tool, arguments, preview, token, context)
        answer = elicited(tool, arguments, preview['plan'], context) unless token
        return answer if answer.is_a?(MCP::Server::InputRequiredResult)
        return run(tool.argv.call(arguments), preview['plan']) if answer == :accepted
        return declined(preview) if answer == :declined

        @confirmation.required(tool, arguments, preview, token)
      end

      # The form's request state is a token signed for `form:TOOL`, so the client's echo binds the
      # answer to this plan and expires like a confirm_token, and it cannot be passed off as a
      # confirm_token itself
      def elicited(tool, arguments, plan, context)
        name = "form:#{tool.name}"
        state = context.request_state if context.respond_to?(:request_state)
        unless state
          issue = -> { @confirmation.issue(name, arguments, plan) }
          return @elicitation.ask(context, tool, plan, state: issue)
        end

        @elicitation.answer(context, tool, fits: @confirmation.valid?(state, name, arguments, plan))
      end

      def declined(preview)
        preview.merge('status' => 'cancelled', 'dry_run' => false)
      end

      # --yes covers changes undo can revert. A change it cannot revert (removing a worktree with
      # ignored files) asks for the command's own token; the MCP token confirmed the same plan,
      # so it is passed on, but only when the command still plans exactly that.
      def run(argv, plan)
        result = @runner.call([*argv, '--yes'])
        cli_token = result.dig('error', 'confirm_token')
        return result unless result['status'] == 'confirmation_required' && cli_token
        return result unless result['plan'] == plan

        @runner.call([*argv, '--confirm', cli_token])
      end
    end
  end
end
