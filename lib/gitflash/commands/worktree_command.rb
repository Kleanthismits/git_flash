# frozen_string_literal: true

module Gitflash
  module Commands
    # Shared lookup for the `worktree` commands that act on one worktree
    class WorktreeCommand < Base
      private

      def worktrees
        @worktrees ||= Worktrees.new(repo: repo)
      end

      # The worktree named by a path or a branch; raises `unknown_worktree` when none matches
      # A target that names one worktree by path and another by branch is refused, so a command
      # never acts on the worktree the caller did not mean
      def find!(target, list = worktrees.list)
        path = expand(target)
        found = list.select { |worktree| worktree.path == path || worktree.branch == target }
        usage_error!('unknown_worktree', "Unknown worktree: #{target}") if found.empty?
        return found.first if found.one?

        paths = found.map { |worktree| TerminalText.line(worktree.path) }.join(', ')
        usage_error!('invalid_usage', "#{target} names more than one worktree (#{paths}); " \
                                      'pass the full path')
      end

      # File.expand_path, but `~name` for an unknown user is a usage error, not a crash
      def expand(path)
        File.expand_path(path)
      rescue ArgumentError => e
        usage_error!('invalid_options', "Cannot read the path #{path}: #{e.message}")
      end

      def refuse_main!(worktree, action)
        return unless worktree.main?

        usage_error!('protected_worktree',
                     "#{worktree.path} is the main checkout; cannot #{action}")
      end
    end
  end
end
