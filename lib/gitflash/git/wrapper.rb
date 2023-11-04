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
          bash.exec('git branch --show-current').strip
        end

        def checkout(branch)
          bash.system_exec('git', 'checkout', branch)
        end

        def delete(branch)
          bash.system_exec('git', 'branch', '-D', *branch)
        end

        def reset(commit_hash:, hard:)
          params = [].tap do |ar|
            ar << '--hard' if hard
          end

          bash.system_exec('git', 'reset', *params, commit_hash)
        end

        def branch_commits
          commits_string = bash.exec('git log --oneline')
          {}.tap do |hsh|
            commits_string.each_line do |line|
              parts = line.strip.split
              commit_code = parts[0]
              commit_name = parts[1..].join(' ')
              hsh[commit_name] = commit_code
            end
          end
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
          bash.exec('git branch').strip.split("\n").map(&:strip)
        end

        def bash
          BashCommand
        end
      end
    end
  end
end
