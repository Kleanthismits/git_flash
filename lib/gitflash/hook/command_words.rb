# frozen_string_literal: true

require 'shellwords'

module Gitflash
  module Hook
    # The words of one command: without subshell brackets, redirections, keywords like `then`,
    # environment assignments and wrappers like `sudo -u me`
    class CommandWords
      # Shell words that can come before a command: `if git ...`, `then git ...`, `! git ...`
      KEYWORDS = %w[if then else elif do while until !].freeze
      REDIRECTION = /\A\d*(?:[<>]{1,2}|&>)/
      # A redirection whose target is the next word (`>`, `2>>`), not part of it (`>out`)
      BARE_REDIRECTION = /#{REDIRECTION}\z/
      ASSIGNMENT = /\A\w+=/

      # words: the command and its arguments; env: the assignments before it, as a Hash;
      # chdir: the directory a wrapper switches to (`sudo -D DIR`, `env -C DIR`), or nil
      attr_reader :words, :env, :chdir

      def initialize(segment)
        @env = {}
        @chdir = nil
        @words = strip(without_redirections(split(segment).map { |word| unwrap(word) }))
      end

      private

      def strip(words)
        loop do
          words = strip_assignments(words.drop_while { |word| KEYWORDS.include?(word) })
          stripped, dir = Wrappers.strip(words)
          return words if stripped == words

          words = stripped
          @chdir = dir || @chdir
        end
      end

      def strip_assignments(words)
        while (word = words.first)&.match?(ASSIGNMENT)
          name, value = word.split('=', 2)
          @env[name] = value
          words = words.drop(1)
        end
        words
      end

      # Drops `> file`, `2>&1`, `< list` and the like, which are not arguments
      def without_redirections(words)
        skip = false
        words.reject do |word|
          next (skip = false) || true if skip

          skip = word.match?(BARE_REDIRECTION)
          word.match?(REDIRECTION)
        end
      end

      def split(segment)
        Shellwords.split(segment)
      rescue ArgumentError
        segment.split
      end

      def unwrap(word)
        word.delete_prefix('(').delete_prefix('{').delete_suffix(')').delete_suffix('}')
      end
    end
  end
end
