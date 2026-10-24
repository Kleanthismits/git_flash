# frozen_string_literal: true

module Gitflash
  module Hook
    # How the hook reads a path from a command line, without a shell to run it
    module Paths
      # A directory the hook guessed because the shell decides the real one when it runs
      # (`cd "$REPO"`): the hook's cwd, or a path relative to it. A snapshot there may not cover
      # the repository the command changes, and the hook says so.
      class Guessed < String; end

      module_function

      # The directory after `cd PATH` or `git -C PATH` from dir. A path the shell decides falls
      # back to `fallback` (the directory Claude runs in) as a Guessed directory, and a relative
      # path from a guessed directory stays guessed.
      def change_dir(path, dir, fallback)
        return Guessed.new(fallback) if unresolved?(path)

        resolved = expand(path, dir)
        dir.is_a?(Guessed) && !absolute?(path) ? Guessed.new(resolved) : resolved
      end

      def guessed?(dir)
        dir.is_a?(Guessed)
      end

      def absolute?(path)
        path.start_with?('/')
      end

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
