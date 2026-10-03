# frozen_string_literal: true

require 'json'
require 'json_schemer'
require 'stringio'

# Runs the CLI in-process and captures stdout, stderr and the exit status
module CliHelper
  SCHEMA = JSONSchemer.schema(Pathname.new(Gitflash::Cli::SCHEMA_PATH))

  # Parsed --json output. Fails when the output does not match schema/v1.json.
  CliRun = Struct.new(:stdout, :stderr, :status) do
    def json
      document = JSON.parse(stdout)
      errors = SCHEMA.validate(document).map { |error| error['error'] }
      raise "JSON output does not match schema/v1.json: #{errors.join('; ')}" if errors.any?

      document
    end
  end

  def run_cli(*args)
    stdout = StringIO.new
    stderr = StringIO.new
    original = [$stdout, $stderr]
    $stdout = stdout
    $stderr = stderr
    status = 0
    begin
      Gitflash::Cli.start(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout, $stderr = original
    end
    CliRun.new(stdout.string, stderr.string, status)
  end
end

RSpec.configure do |config|
  config.include CliHelper
end
