# frozen_string_literal: true

require 'json'

module Gitflash
  # Everything the user sees: human text or JSON, menus and confirmations.
  # Menus and confirmations are only shown in a terminal and never in JSON mode.
  #
  # JSON output always uses the same envelope (see schema/v1.json):
  #   { schema, command, ok, status, dry_run, plan?, result?, undo?, error? }
  class Ui
    JSON_SCHEMA_VERSION = 1
    OK_STATUSES = %w[done planned noop cancelled].freeze

    def initialize(command:, json: false, yes: false, dry_run: false)
      @command = command
      @json = json
      @yes = yes
      @dry_run = dry_run
    end

    def json?
      @json
    end

    def dry_run?
      @dry_run
    end

    def interactive?
      !json? && $stdin.tty?
    end

    # Reports the outcome of a command and returns its exit status.
    # `status` is one of done, planned, noop, cancelled or failed.
    # `fields` may hold plan, result, error and undo (the snapshot that reverts the change).
    def report(status:, text:, **fields)
      if json?
        $stdout.puts JSON.generate(envelope(status: status, **fields))
      else
        $stdout.puts text
        $stdout.puts "Undo with: gitflash undo #{fields[:undo].id}" if fields[:undo]
      end
      OK_STATUSES.include?(status) ? 0 : 1
    end

    def error(error)
      if json?
        details = { code: error.code, message: error.message, exit_code: error.exit_code }
        $stdout.puts JSON.generate(envelope(status: error.status, plan: error.plan, error: details))
      else
        warn error.message
      end
    end

    def select(message, choices, **)
      prompt.select(message, choices, **)
    end

    def multi_select(message, choices, **)
      prompt.multi_select(message, choices, **)
    end

    # True when the action may proceed: --yes was given or the user confirmed in a terminal.
    # Raises ConfirmationRequired, carrying the plan, when nobody can confirm.
    def confirm?(summary, plan:)
      return true if @yes

      message = "#{summary}\nRe-run with --yes to confirm."
      raise ConfirmationRequired.new(message, plan: plan) unless interactive?

      prompt.proceed_with_warning(summary) { true } == true
    end

    private

    def envelope(status:, plan: nil, result: nil, error: nil, undo: nil)
      {
        schema: JSON_SCHEMA_VERSION,
        command: @command,
        ok: OK_STATUSES.include?(status),
        status: status,
        dry_run: dry_run?,
        plan: plan,
        result: result,
        undo: undo && { snapshot: undo.id, command: "gitflash undo #{undo.id}" },
        error: error
      }.compact
    end

    def prompt
      @prompt ||= Prompt.create
    end
  end
end
