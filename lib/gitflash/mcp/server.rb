# frozen_string_literal: true

require 'json'
require 'mcp'

module Gitflash
  module Mcp
    # `gitflash mcp`: an MCP server on stdio for the repository in its working directory.
    # Every tool runs a gitflash command (Runner) and answers with its JSON v1 envelope, so the
    # tools and the CLI share one contract. Destructive tools take two calls: the first returns
    # the plan with status `confirmation_required` and `error.confirm_token`, the second passes
    # that token as `confirm_token` and makes exactly that change (Confirmation).
    class Server
      INSTRUCTIONS = <<~TEXT
        gitflash works on the git repository this server was started in. Every result is the
        gitflash JSON envelope (`gitflash schema` describes it): check `ok`, `status` and
        `error.code`. Changes save a snapshot first; keep `undo.command` and tell the user how to
        undo. Destructive tools answer the first call with the plan, status
        `confirmation_required` and `error.confirm_token`: show the plan to the user, and only
        when it is what they asked for, call the tool again with the same arguments and
        `confirm_token`. A token expires after 5 minutes and only confirms that plan.
      TEXT

      ANNOTATIONS = {
        read: { read_only_hint: true, destructive_hint: false, idempotent_hint: true },
        additive: { read_only_hint: false, destructive_hint: false, idempotent_hint: false },
        destructive: { read_only_hint: false, destructive_hint: true, idempotent_hint: false }
      }.freeze

      CONFIRM_TOKEN = { type: 'string',
                        description: 'The error.confirm_token of the first call, to make the ' \
                                     'change it planned' }.freeze

      def initialize(runner: Runner.new, confirmation: Confirmation.new)
        @runner = runner
        @confirmation = confirmation
      end

      def start
        MCP::Server::Transports::StdioTransport.new(mcp_server).open
      end

      def mcp_server
        MCP::Server.new(name: 'gitflash', version: VERSION, instructions: INSTRUCTIONS,
                        tools: Tools::ALL.map { |tool| mcp_tool(tool) })
      end

      # The envelope a tool answers with
      def call(tool, arguments)
        arguments = arguments.transform_keys(&:to_sym)
        return destructive(tool, arguments) if tool.kind == :destructive

        @runner.call(tool.argv.call(arguments))
      end

      private

      def mcp_tool(tool)
        server = self
        properties = tool.properties
        properties = properties.merge(confirm_token: CONFIRM_TOKEN) if tool.kind == :destructive
        MCP::Tool.define(
          name: tool.name, description: tool.description,
          input_schema: { properties: properties, required: tool.required,
                          additionalProperties: false },
          annotations: ANNOTATIONS.fetch(tool.kind).merge(open_world_hint: false)
        ) do |server_context: nil, **arguments| # rubocop:disable Lint/UnusedBlockArgument
          server.send(:respond, server.call(tool, arguments))
        end
      end

      def respond(envelope)
        MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(envelope) }],
                                structured_content: envelope,
                                error: %w[error failed].include?(envelope['status']))
      end

      # The dry run gives the plan. Without a valid token for it, the plan is returned with a new
      # token; with one the change is made. Nothing to do or an error is returned as it is.
      def destructive(tool, arguments)
        token = arguments.delete(:confirm_token)
        arguments = arguments.sort.to_h
        argv = tool.argv.call(arguments)
        preview = @runner.call([*argv, '--dry-run'])
        return preview unless preview['status'] == 'planned'

        confirmed = token && @confirmation.valid?(token, tool.name, arguments, preview['plan'])
        return confirm(tool, arguments, preview, token) unless confirmed

        run(argv, preview['plan'])
      end

      def confirm(tool, arguments, preview, token)
        token_note = token ? 'The confirm_token has expired or does not match this plan. ' : ''
        new_token = @confirmation.issue(tool.name, arguments, preview['plan'])
        message = "#{token_note}Review the plan; to make this change, call #{tool.name} again " \
                  "with the same arguments and confirm_token #{new_token} (valid until " \
                  "#{Confirmation.expires_at(new_token)})."
        preview.merge('ok' => false, 'status' => 'confirmation_required', 'dry_run' => false,
                      'error' => { 'code' => 'confirmation_required', 'message' => message,
                                   'exit_code' => 2, 'confirm_token' => new_token })
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
