# frozen_string_literal: true

module Gitflash
  module Hook
    # What a snapshot cannot bring back: ignored files a command deletes (`git clean -x`,
    # `git worktree remove`) and untracked files too large to save. The hook names them so the
    # agent is not told everything can be undone.
    module Losses
      SHOWN = 5

      module_function

      # A note for Claude about the targets and snapshots, or nil when nothing is lost for good
      def note(saved, targets)
        notes = targets.select(&:ignored).filter_map { |target| ignored_note(target) }
        notes += saved.filter_map { |_target, snapshot| skipped_note(snapshot) }
        notes.empty? ? nil : notes.join(' ')
      end

      def ignored_note(target)
        files = ignored_files(target.dir)
        return nil if files.empty?

        "`#{target.command}` also deletes ignored files in #{target.dir}, which no snapshot " \
          "saves: #{listing(files)}."
      end

      def skipped_note(snapshot)
        return nil if snapshot.skipped_files.empty?

        "Snapshot #{snapshot.id} left out untracked files over 50 MB, which cannot be restored: " \
          "#{listing(snapshot.skipped_files)}."
      end

      # Ignored files and directories git reports in the directory (a whole ignored directory is
      # one entry)
      def ignored_files(dir)
        stdout, _stderr, success = Git::BashCommand.capture(
          'git', '-C', dir, 'ls-files', '-z', '--others', '--ignored', '--exclude-standard',
          '--directory'
        )
        success ? stdout.split("\0") : []
      end

      def listing(files)
        shown = files.first(SHOWN).map { |file| TerminalText.line(file) }.join(', ')
        files.size > SHOWN ? "#{shown} and #{files.size - SHOWN} more" : shown
      end
    end
  end
end
