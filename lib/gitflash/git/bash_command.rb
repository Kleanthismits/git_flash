# frozen_string_literal: true

require 'open3'

module Gitflash
  module Git
    class BashCommand
      class << self
        # Runs a command without a shell and returns its stdout.
        # Raises CommandError when the command exits with a non-zero status.
        def exec(*args, env: {})
          stdout, stderr, success = capture(*args, env: env)
          raise CommandError, "#{args.join(' ')} failed: #{stderr.strip}" unless success

          stdout
        end

        # Runs a command without a shell and returns [stdout, stderr, success].
        # `env` adds environment variables for this command only.
        def capture(*args, env: {})
          stdout, stderr, status = Open3.capture3(env, *args)
          [stdout, stderr, status.success?]
        rescue SystemCallError => e
          raise CommandError, "#{args.join(' ')} failed: #{e.message}"
        end
      end
    end
  end
end
