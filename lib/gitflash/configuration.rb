require 'yaml'

module Gitflash
  module Configuration
    module Descriptions
      def descriptions
        @descriptions ||= load_descriptions
      end

      private

      def load_descriptions
        transform_to_struct(YAML.load_file('command_descriptions.yml'))
      end

      def transform_to_struct(data)
        return data unless data.is_a? Hash

        keys = data.keys.map(&:to_sym)
        Struct.new(*keys).new(*data.values).tap do |st|
          keys.each do |method|
            st.send("#{method}=".to_sym, transform_to_struct(st.send(method)))
          end
        end
      end
    end
  end
end
