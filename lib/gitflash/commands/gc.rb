# frozen_string_literal: true

module Gitflash
  module Commands
    # Deletes snapshots older than --older-than DAYS (default 30, at least 1). Git frees their
    # objects at its next garbage collection. A whole number of days is required: 0 or a
    # negative number would select every snapshot, including the one just taken.
    class Gc < Base
      DEFAULT_DAYS = 30

      def call
        days = older_than_days
        old = older_than(days)
        plan = { older_than_days: days, snapshots: old.map(&:id) }
        return nothing(plan) if old.empty?

        delete(plan, "#{old.size} snapshots older than #{days} days")
      end

      private

      def older_than_days
        value = options[:older_than]
        return DEFAULT_DAYS if value.nil?

        days = Integer(value.to_s, 10, exception: false)
        return days if days&.positive?

        usage_error!('invalid_options',
                     "--older-than needs a whole number of days, 1 or more, got '#{value}'")
      end

      def delete(plan, text)
        return planned(plan, "Would delete #{text}") if ui.dry_run?

        # Deleted snapshots are gone for good: no snapshot of the snapshots is kept
        summary = "You are about to delete #{text}"
        return cancelled(plan) unless ui.confirm?(summary, plan: plan, irreversible: true)

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
