# frozen_string_literal: true

module Gitflash
  module Commands
    # Saves the current state on request, for example before a risky step
    class SnapshotCreate < Base
      def call
        snapshot = take_snapshot(options[:message] || 'gitflash snapshot', scope: scope)
        ui.report(status: 'done', result: { snapshot: snapshot.to_h }, undo: snapshot,
                  text: text(snapshot))
      end

      private

      def scope
        scope = options[:scope] || Snapshots::SCOPES
        invalid = scope - Snapshots::SCOPES
        usage_error!('invalid_options', "Unknown scope: #{invalid.join(', ')}") if invalid.any?
        scope
      end

      def text(snapshot)
        lines = ["Saved snapshot #{snapshot.id}"]
        lines << "Skipped large untracked files: #{snapshot.skipped_files.join(', ')}" if
          snapshot.skipped_files.any?
        lines << "Left out by snapshot_exclude: #{snapshot.excluded_files.join(', ')}" if
          snapshot.excluded_files.any?
        lines.join("\n")
      end
    end
  end
end
