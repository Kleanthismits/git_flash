# frozen_string_literal: true

module Gitflash
  module Git
    # Runs every git command inside another directory (`git -C DIR ...`). It has the same
    # interface as BashCommand, so StateCapture, Snapshots and Restore can work on a linked
    # worktree without knowing about it.
    class InDirectory
      def initialize(path, bash: BashCommand)
        @path = path
        @bash = bash
      end

      def exec(*args, env: {})
        @bash.exec(*scoped(args), env: env)
      end

      def capture(*args, env: {})
        @bash.capture(*scoped(args), env: env)
      end

      private

      def scoped(args)
        args.first == 'git' ? ['git', '-C', @path, *args.drop(1)] : args
      end
    end
  end
end
