# frozen_string_literal: true

require 'digest'
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

    def initialize(command:, json: false, yes: false, dry_run: false, confirm: nil)
      @command = command
      @json = json
      @yes = yes
      @dry_run = dry_run
      @confirm = confirm
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
        $stdout.puts TerminalText.safe(text)
        $stdout.puts undo_hint(fields[:undo]) if fields[:undo]
      end
      OK_STATUSES.include?(status) ? 0 : 1
    end

    def error(error)
      if json?
        details = { code: error.code, message: error.message, exit_code: error.exit_code,
                    confirm_token: error.respond_to?(:confirm_token) ? error.confirm_token : nil }
                  .compact
        $stdout.puts JSON.generate(envelope(status: error.status, plan: error.plan, error: details))
      else
        warn TerminalText.safe(error.message)
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
    #
    # An irreversible action (one `gitflash undo` cannot revert) is not covered by --yes: it
    # needs --confirm with a token made from its plan, or the token typed in a terminal. The
    # token changes with the plan, so a confirmation never carries over to a different change.
    def confirm?(summary, plan:, irreversible: false)
      return confirm_irreversible?(summary, plan) if irreversible
      return true if @yes

      message = "#{summary}\nRe-run with --yes to confirm."
      raise ConfirmationRequired.new(message, plan: plan) unless interactive?

      prompt.proceed_with_warning(TerminalText.safe(summary)) { true } == true
    end

    # The token that confirms this plan with --confirm
    def self.confirm_token(plan)
      Digest::SHA256.hexdigest(JSON.generate(plan))[0, 8]
    end

    private

    def confirm_irreversible?(summary, plan)
      token = self.class.confirm_token(plan)
      return true if @confirm == token

      summary = "#{summary}\ngitflash undo cannot revert this."
      unless interactive?
        message = "#{summary}\nRe-run with --confirm #{token} to confirm (--yes is not enough)."
        raise ConfirmationRequired.new(message, plan: plan, confirm_token: token)
      end

      warn TerminalText.safe(summary)
      prompt.ask("Type #{token} to confirm:").to_s.strip == token
    end

    def envelope(status:, plan: nil, result: nil, error: nil, undo: nil)
      {
        schema: JSON_SCHEMA_VERSION,
        command: @command,
        ok: OK_STATUSES.include?(status),
        status: status,
        dry_run: dry_run?,
        plan: plan,
        result: result,
        undo: undo && { snapshot: undo.id, command: "gitflash undo #{undo.id}",
                        reused: (true if undo.reused?) }.compact,
        error: error
      }.compact
    end

    def undo_hint(undo)
      note = undo.reused? ? ' (an earlier snapshot: nothing had changed since it was taken)' : ''
      "Undo with: gitflash undo #{undo.id}#{note}"
    end

    def prompt
      @prompt ||= Prompt.create
    end
  end
end
