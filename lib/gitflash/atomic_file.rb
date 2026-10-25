# frozen_string_literal: true

require 'fileutils'
require 'tempfile'

module Gitflash
  # Replaces a file in one step: the text goes to a temporary file next to it, which is then
  # renamed into place, so a crash never leaves half a file. The file keeps its permissions,
  # and a symbolic link (dotfiles) is followed, so the link stays and its target changes.
  module AtomicFile
    module_function

    def write(path, text)
      path = link_target(path) if File.symlink?(path)
      FileUtils.mkdir_p(File.dirname(path))
      file = Tempfile.create(['.gitflash', File.extname(path)], File.dirname(path))
      replace(file, path, text)
    end

    # Where a link points, also when that file does not exist yet: the link's directory and the
    # target's directory are resolved, the file name is kept
    def link_target(path)
      target = File.expand_path(File.readlink(path), File.dirname(path))
      return File.realpath(target) if File.exist?(target)

      File.join(File.realpath(File.dirname(target)), File.basename(target))
    end

    def replace(file, path, text)
      file.write(text)
      file.flush
      file.fsync
      file.close
      File.chmod(File.stat(path).mode & 0o7777, file.path) if File.exist?(path)
      File.rename(file.path, path)
    ensure
      FileUtils.rm_f(file.path) if file && File.exist?(file.path)
    end
  end
end
