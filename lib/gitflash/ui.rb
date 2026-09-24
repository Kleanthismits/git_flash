# frozen_string_literal: true

require 'json'

module Gitflash
  # Everything the user sees: human text or JSON, menus and confirmations.
  # Menus and confirmations are only shown in a terminal and never in JSON mode.
  class Ui
    JSON_SCHEMA_VERSION = 1

    def initialize(json: false, yes: false, dry_run: false)
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

    # Prints `payload` as JSON in JSON mode, else prints `text`
    def emit(payload, text = nil)
      if json?
        $stdout.puts JSON.generate({ schema: JSON_SCHEMA_VERSION }.merge(payload))
      elsif text
        $stdout.puts text
      end
    end

    def error(error)
      if json?
        details = { message: error.message, exit_code: error.exit_code,
                    details: error.details }.compact
        $stdout.puts JSON.generate({ schema: JSON_SCHEMA_VERSION, error: details })
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
    # Raises ConfirmationRequired when nobody can confirm.
    def confirm?(summary, details: nil)
      return true if @yes
      unless interactive?
        raise ConfirmationRequired.new("#{summary}\nRe-run with --yes to confirm.",
                                       details: details)
      end

      prompt.proceed_with_warning(summary) { true } == true
    end

    private

    def prompt
      @prompt ||= Prompt.create
    end
  end
end
