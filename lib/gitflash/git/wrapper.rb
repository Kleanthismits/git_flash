# frozen_string_literal: true

module Gitflash
  module Git
    class Wrapper
      HIDDEN_BRANCHES = %w[–show-current].freeze

      class << self
        def local_branches(current: true, master: true)
          formatted_branches.tap do |branches|
            hidden_branches(current, master).each { |br| branches.delete(br) }
          end
        end

        def all_local_branches
          formatted_branches
        end

        def current_branch
          exec('git branch --show-current').strip
        end

        def checkout(branch)
          exec "git checkout #{branch}"
        end

        def delete(selection)
          `git branch -D #{selection.join(' ')}`
        end

        private

        def hidden_branches(current, master)
          [].tap { |hb|
            hb.push('master') unless master
            hb.push('main') unless master
            hb.push(current_branch) unless current
          } + HIDDEN_BRANCHES
        end

        def formatted_branches
          raw_branches.map do |str|
            next str unless str.start_with?('* ')

            str.gsub('* ', '')
          end
        end

        def raw_branches
          exec('git branch').strip.split("\n").map(&:strip)
        end

        def exec(command)
          BashCommand.exec(command)
        end
      end
    end
  end
end
