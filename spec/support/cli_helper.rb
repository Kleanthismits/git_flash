# frozen_string_literal: true

require 'json'
require 'stringio'

# Runs the CLI in-process and captures stdout, stderr and the exit status
module CliHelper
  CliRun = Struct.new(:stdout, :stderr, :status) do
    def json
      JSON.parse(stdout)
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
