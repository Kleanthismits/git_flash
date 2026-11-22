# frozen_string_literal: true

require 'yaml'

module Gitflash
  module Configuration
    # Help texts from command_descriptions.yml, read once and frozen.
    # Thor classes extend it and call `description(:branches).short` in their `desc` lines.
    module Descriptions
      FILE = File.expand_path('../../command_descriptions.yml', __dir__)

      # `short` is nil for an entry that only overrides the long help
      Description = Data.define(:short, :long)

      def self.all
        @all ||= YAML.load_file(FILE).to_h { |name, texts|
          [name.to_sym, Description.new(short: texts['short']&.freeze, long: texts['long']&.freeze)]
        }.freeze
      end

      # Raises KeyError naming the entry when command_descriptions.yml has none
      def description(name)
        Descriptions.all.fetch(name)
      end
    end
  end
end
