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
        text = "Saved snapshot #{snapshot.id}"
        return text if snapshot.skipped_files.empty?

        "#{text}\nSkipped large untracked files: #{snapshot.skipped_files.join(', ')}"
      end
    end
  end
end
