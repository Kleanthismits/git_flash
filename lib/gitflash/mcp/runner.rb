# frozen_string_literal: true

require 'json'
require 'open3'

module Gitflash
  module Mcp
    # Runs one gitflash command with --json in a child process and returns its envelope.
    # A child process keeps the MCP connection safe: commands print to stdout, which is the
    # stdio transport here, and an error in a command can never take the server down. The child
    # runs this same copy of gitflash, in the server's working directory, without a terminal,
    # so it never waits for input.
    class Runner
      LIB = File.expand_path('../..', __dir__)
      BIN = File.expand_path('../../../bin/gitflash', __dir__)

      def initialize(dir: Dir.pwd)
        @dir = dir
      end

      def call(argv)
        stdout, stderr, status = Open3.capture3(Gem.ruby, '-I', LIB, BIN, *argv, '--json',
                                                chdir: @dir, stdin_data: '')
        JSON.parse(stdout)
      rescue JSON::ParserError
        failed(argv, status, stderr)
      end

      private

      # A command that printed no envelope, which only happens when gitflash itself breaks
      def failed(argv, status, stderr)
        message = "gitflash #{argv.first} printed no JSON (exit #{status&.exitstatus}): " \
                  "#{stderr.to_s.strip[0, 2000]}"
        { 'schema' => Ui::JSON_SCHEMA_VERSION, 'command' => argv.first, 'ok' => false,
          'status' => 'error', 'dry_run' => false,
          'error' => { 'code' => 'failed', 'message' => message, 'exit_code' => 1 } }
      end
    end
  end
end
