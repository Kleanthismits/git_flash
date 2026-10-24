# frozen_string_literal: true

module Gitflash
  # Checks a snapshot read from a ref before gitflash trusts it. Anyone with write access to the
  # repository can create such a ref, and its fields go into git commands and paths.
  module SnapshotCheck
    SHA = /\A\h{40}(?:\h{24})?\z/
    # What git accepts in a branch name, roughly: no control characters, spaces, `~^:?*[\`, `..`
    # or `@{`, no leading `-` or `/`, no `//`, no trailing `/`, `.` or `.lock`
    BRANCH = %r{\A(?!-|/)(?!.*(?:\.\.|@\{|//))[^\x00-\x20\x7F~^:?*\[\\]+(?<![/.])(?<!\.lock)\z}

    module_function

    # Why the snapshot read from ref cannot be trusted, or nil
    def problem(ref, snapshot)
      expected = Snapshots::REF_PREFIX + snapshot.id.to_s
      return 'its name does not match its id' unless ref == expected
      return 'a commit id is not a full hex SHA' unless snapshot.object_ids.all? { |id| sha?(id) }
      return 'a branch name is not valid' unless branch_names(snapshot).all?(BRANCH)
      return 'worktree_path is not an absolute path' unless path?(snapshot.worktree_path)

      nil
    end

    def sha?(id)
      id.is_a?(String) && id.match?(SHA)
    end

    def branch_names(snapshot)
      (snapshot.branches.keys + [snapshot.head[:branch]]).compact.map(&:to_s)
    end

    # nil for snapshots from before worktree_path was recorded
    def path?(path)
      path.nil? || (path.is_a?(String) && path.start_with?('/') && !path.match?(/[\x00-\x1F]/))
    end
  end
end
