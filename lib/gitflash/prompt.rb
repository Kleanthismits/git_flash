# frozen_string_literal: true

require 'tty-prompt'
require 'pry'

module GitFlash
  # A wrapper class for TTY::Prompt gem
  class Prompt < TTY::Prompt
    class << self
      def create(options = {})
        new(options)
      end
    end
    def initialize(options)
      super(**default_create_options(options))
    end

    def select(message, collection, options = {})
      super(message, collection, default_select_options(options))
    end

    private

    def default_create_options(options)
      {
        interrupt: :exit,
        quiet: true
      }.merge(options)
    end

    def default_select_options(options)
      {
        cycle: true,
        per_page: 50,
        filter: true,
        symbols: { marker: '>' }
      }.merge(options)
    end
  end
end
