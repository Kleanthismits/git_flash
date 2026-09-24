# frozen_string_literal: true

require 'open3'

module Gitflash
  module Git
    class BashCommand
      class << self
        # Runs a command without a shell and returns its stdout.
        # Raises CommandError when the command exits with a non-zero status.
        def exec(*args)
          stdout, stderr, status = Open3.capture3(*args)
          raise CommandError, "#{args.join(' ')} failed: #{stderr.strip}" unless status.success?

          stdout
        rescue SystemCallError => e
          raise CommandError, "#{args.join(' ')} failed: #{e.message}"
        end

        def system_exec(*args)
          system(*args)
        end
      end
    end
  end
end
