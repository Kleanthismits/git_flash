# frozen_string_literal: true

module Gitflash
  module Hook
    # How the hook reads a path from a command line, without a shell to run it
    module Paths
      module_function

      # File.expand_path, except that `~user` for an unknown user is kept as a literal name
      # instead of raising: an error here must not stop the hook from deciding
      def expand(path, dir)
        File.expand_path(path, dir)
      rescue ArgumentError
        File.join(File.expand_path(dir), path)
      end

      # Whether the shell decides the path when it runs: a variable, a command substitution or
      # `cd -`. The text alone does not say which directory that is.
      def unresolved?(path)
        path == '-' || path.match?(/[$`]/)
      end
    end
  end
end
