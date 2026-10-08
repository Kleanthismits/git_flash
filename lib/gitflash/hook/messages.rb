# frozen_string_literal: true

module Gitflash
  module Hook
    # What the PreToolUse hook tells Claude about a risky command
    module Messages
      module_function

      def saved(saved)
        notes = saved.map { |target, snap| "snapshot #{snap.id} before `#{target.command}`" }
        "gitflash saved #{notes.join('; ')}. If this discards work that was still " \
          "needed, restore it with `gitflash undo #{saved.last[1].id}` " \
          '(list snapshots with `gitflash snapshots`).'
      end

      def unsaved(targets)
        "gitflash could not save a snapshot before #{commands(targets)} (not inside a git work " \
          'tree), so nothing can be restored with `gitflash undo`.'
      end

      def denial(targets)
        "gitflash blocked #{commands(targets)}: it can discard work git cannot restore. " \
          'Use the gitflash equivalent (gitflash reset, gitflash delete, ...), which ' \
          'saves a snapshot first, or run `gitflash snapshot` before retrying.'
      end

      def commands(targets)
        targets.map { |target| "`#{target.command}`" }.join(', ')
      end
    end
  end
end
