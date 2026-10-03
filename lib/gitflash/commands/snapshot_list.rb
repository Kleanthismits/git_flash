# frozen_string_literal: true

module Gitflash
  module Commands
    # Lists snapshots, newest first
    class SnapshotList < Base
      def call
        list = snapshots.list
        text = list.empty? ? 'No snapshots' : list.map { |snapshot| row(snapshot) }.join("\n")
        ui.report(status: 'done', result: { snapshots: list.map(&:to_h) }, text: text)
      end

      private

      def row(snapshot)
        "#{snapshot.id}  #{snapshot.scope.join(',').ljust(28)}  #{snapshot.reason}"
      end
    end
  end
end
