# frozen_string_literal: true

module Gitflash
  module Hook
    # What the PreToolUse hook tells Claude about a risky command
    module Messages
      module_function

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
