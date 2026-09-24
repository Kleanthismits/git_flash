# frozen_string_literal: true

require 'yaml'

module Gitflash
  module Configuration
    module Descriptions
      def descriptions
        @descriptions ||= load_descriptions
      end

      private

      def load_descriptions
        file = File.expand_path('../../command_descriptions.yml', __dir__)
        transform_to_struct(YAML.load_file(file))
      end

      def transform_to_struct(data)
        return data unless data.is_a? Hash

        keys = data.keys.map(&:to_sym)
        Struct.new(*keys).new(*data.values).tap do |st|
          keys.each do |method|
            st.public_send("#{method}=", transform_to_struct(st.public_send(method)))
          end
        end
      end
    end
  end
end
