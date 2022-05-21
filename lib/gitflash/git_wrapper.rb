# frozen_string_literal: true

require 'pry'

module GitFlash
  class GitWrapper
    HIDDEN_BRANCHES = %w[–show-current].freeze

    class << self
      def get_local_branches(current: true, master: true)
        format_raw_branches(raw_branches).tap do |branches|
          hidden_branches(current, master).each { |br| branches.delete(br) }
        end
      end

      def current_branch
        `git branch | grep '\''^\*'\'' | cut -d'\'' '\'' -f2 | tr -d '\''\n'\''`
      end

      def checkout(branch)
        `git checkout #{branch}`
      end

      def delete(selection)
        `git branch -D #{selection.join(' ')}`
      end

      private

      def hidden_branches(current, master)
        [].tap do |hb|
          hb.push('master') unless master
          hb.push('main') unless master
          hb.push(current_branch) unless current
        end + HIDDEN_BRANCHES
      end

      def raw_branches
        `git branch`.strip.split("\n").map(&:strip)
      end

      def format_raw_branches(raw_branches)
        raw_branches.map do |str|
          next str unless str.start_with?('* ')

          str.gsub('* ', '')
        end
      end
    end
  end
end
