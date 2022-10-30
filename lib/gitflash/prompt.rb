# frozen_string_literal: true

require 'tty-prompt'

module Gitflash
  # A wrapper class for TTY::Prompt gem
  class Prompt
    class << self
      def create(options: {})
        new(options)
      end
    end

    def initialize(options)
      @prompt = TTY::Prompt.new(**default_create_options(options))
    end

    def select(message, collection, options = {})
      prompt.select(message, collection, default_select_options(options))
    end

    private

    attr_reader :prompt

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
