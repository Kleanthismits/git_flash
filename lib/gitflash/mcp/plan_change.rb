# frozen_string_literal: true

require 'json'
require 'json_schemer'

module Gitflash
  module Mcp
    # The plan_change tool: the dry run of a destructive tool and a confirm_token for it, as a
    # read-only call. The client has only checked that `arguments` is an object, so they are
    # checked against the target tool's schema here.
    class PlanChange
      def initialize(runner, confirmation)
        @runner = runner
        @confirmation = confirmation
      end

      def call(arguments)
        target = Tools::ALL.find { |tool| tool.kind == :destructive && tool.name == arguments[:tool] }
        return invalid("Unknown destructive tool #{arguments[:tool].inspect}") unless target

        check(target, JSON.parse(JSON.generate(arguments[:arguments] || {})))
      end

      private

      def check(target, arguments)
        problems = problems(target, arguments)
        return plan(target, arguments.transform_keys(&:to_sym).sort.to_h) if problems.empty?

        invalid("Invalid arguments for #{target.name}: #{problems.join('; ')}")
      end

      def plan(target, arguments)
        preview = @runner.call([*target.argv.call(arguments), '--dry-run'])
        return preview unless preview['status'] == 'planned'

        @confirmation.required(target, arguments, preview, nil)
      end

      def problems(target, arguments)
        JSONSchemer.schema(Tools.input_schema(target)).validate(arguments).map do |problem|
          problem['error']
        end
      end

      def invalid(message)
        { 'schema' => Ui::JSON_SCHEMA_VERSION, 'command' => 'gitflash', 'ok' => false,
          'status' => 'error', 'dry_run' => false,
          'error' => { 'code' => 'invalid_options', 'message' => message, 'exit_code' => 2 } }
      end
    end
  end
end
