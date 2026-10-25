# frozen_string_literal: true

module Gitflash
  module Hook
    # What the PreToolUse hook tells Claude about a risky command
    module Messages
      module_function

      # Everything the hook tells Claude about the commands it saved ([target, snapshot] pairs)
      # and the ones it could not save
      def context(saved, unsaved)
        targets = saved.map(&:first) + unsaved
        guessed = targets.select(&:guessed)
        [(saved(saved) unless saved.empty?), (unsaved(unsaved) unless unsaved.empty?),
         (guessed(guessed) unless guessed.empty?), Losses.note(saved, targets)].compact.join(' ')
      end

      def saved(saved)
        notes = saved.map { |target, snap| "snapshot #{snap.id} before `#{target.command}`" }
        "gitflash saved #{notes.join('; ')}. If this discards work that was still needed, " \
          "restore it with #{undo_commands(saved)} (list snapshots with `gitflash snapshots`)."
      end

      # One command per snapshot: with several directories each snapshot belongs to its own
      def undo_commands(saved)
        return "`gitflash undo #{saved.first[1].id}`" if saved.size == 1

        saved.map { |target, snap| "`gitflash undo #{snap.id}` (run in #{target.dir})" }.join(', ')
      end

      def unsaved(targets)
        dirs = targets.map(&:dir).uniq.join(', ')
        "gitflash could not save a snapshot before #{commands(targets)} in #{dirs} (not a git " \
          'work tree, does not exist, or the snapshot failed), so nothing it discards there can ' \
          'be restored with `gitflash undo`. Run `gitflash snapshot` in that repository first ' \
          'if the work matters.'
      end

      # The directory of these commands is decided by the shell (`cd "$REPO"`, `git -C "$X"`),
      # so the snapshot was taken where Claude runs and may not cover what they change
      def guessed(targets)
        "The shell decides where #{commands(targets)} runs, so gitflash could only guess the " \
          "directory (#{targets.map(&:dir).uniq.join(', ')}). If the command changes another " \
          'repository, nothing it discards there can be restored; run `gitflash snapshot` in ' \
          'that repository first if the work matters.'
      end

      def denial(targets)
        "gitflash blocked #{commands(targets)}: it can discard work git cannot restore. " \
          'Use the gitflash equivalent (gitflash reset, gitflash delete, ...), which ' \
          'saves a snapshot first, or run `gitflash snapshot` before retrying.'
      end

      def failure(error)
        "gitflash could not check this command (#{error.message}), so it cannot tell whether " \
          'it discards work git cannot restore. Run `gitflash snapshot` first if it might.'
      end

      def commands(targets)
        targets.map { |target| "`#{target.command}`" }.join(', ')
      end
    end
  end
end
