# frozen_string_literal: true

module Gitflash
  module Commands
    # The selection options shared by `clean` and `wt clean`: --merged, --gone, --stale [DAYS]
    # and --agent. Without any of them merged and gone branches are selected.
    module CleanCriteria
      FLAGS = %i[merged gone stale agent].freeze

      private

      def rules
        given = FLAGS.select { |flag| options[flag] }
        Cleanup::Rules.new(criteria: given.empty? ? Cleanup::DEFAULT_CRITERIA : given,
                           stale_days: stale_days, now: Time.now)
      end

      def stale_days
        value = options[:stale]
        return config.stale_days if value.nil? || value.to_s.empty?

        days = Integer(value, exception: false)
        return days if days&.positive?

        usage_error!('invalid_options', "--stale needs a positive number of days, got '#{value}'")
      end
    end
  end
end
