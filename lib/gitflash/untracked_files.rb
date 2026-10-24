# frozen_string_literal: true

module Gitflash
  # Sizes of untracked files, for StateCapture
  module UntrackedFiles
    module_function

    # [paths up to max bytes, larger paths]. A file removed since `ls-files` ran (a build
    # writing temporary files) is left out, so `git add` is not given a path that is gone.
    def split_by_size(top, paths, max)
      sizes = paths.filter_map do |path|
        [path, File.lstat(File.join(top, path)).size]
      rescue Errno::ENOENT
        nil
      end
      sizes.partition { |_path, size| size <= max }.map { |group| group.map(&:first) }
    end
  end
end
