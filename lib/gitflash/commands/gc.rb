# frozen_string_literal: true

module Gitflash
  module Commands
    # Deletes snapshots older than --older-than DAYS (default 30). Git frees their objects at
    # its next garbage collection.
    class Gc < Base
      DEFAULT_DAYS = 30

      def call
        days = options[:older_than] || DEFAULT_DAYS
        old = older_than(days)
        plan = { older_than_days: days, snapshots: old.map(&:id) }
        return nothing(plan) if old.empty?

        delete(plan, "#{old.size} snapshots older than #{days} days")
      end

      private

      def delete(plan, text)
        return planned(plan, "Would delete #{text}") if ui.dry_run?
        return cancelled(plan) unless ui.confirm?("You are about to delete #{text}", plan: plan)

        plan[:snapshots].each { |id| snapshots.delete(id) }
        ui.report(status: 'done', plan: plan, result: { deleted: plan[:snapshots] },
                  text: "Deleted #{text}")
      end

      def older_than(days)
        cutoff = Time.now - (days * 86_400)
        snapshots.list.select { |snapshot| Time.iso8601(snapshot.created_at) < cutoff }
      end

      def nothing(plan)
        ui.report(status: 'noop', plan: plan, result: { deleted: [] },
                  text: "No snapshots older than #{plan[:older_than_days]} days")
      end
    end
  end
end
