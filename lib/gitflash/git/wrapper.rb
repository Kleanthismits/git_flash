# frozen_string_literal: true

module Gitflash
  module Git
    class Wrapper
      COMMITS_LIMIT = 100

      class << self
        def local_branches(current: true, master: true)
          formatted_branches - hidden_branches(current, master)
        end

        def all_local_branches
          formatted_branches
        end

        def current_branch
          bash.exec('git', 'branch', '--show-current').strip
        end

        def checkout(branch)
          bash.system_exec('git', 'checkout', branch, '--')
        end

        def delete(branch)
          bash.system_exec('git', 'branch', '-D', *branch)
        end

        def reset(commit_hash:, hard:)
          params = [].tap do |ar|
            ar << '--hard' if hard
          end

          bash.system_exec('git', 'reset', *params, commit_hash, '--')
        end

        def branch_commits
          commits_string = bash.exec(
            'git', 'log', "--max-count=#{COMMITS_LIMIT}", '--format=%h%x09%s'
          )
          parse_commits(commits_string)
        rescue CommandError
          # `git log` fails on a branch without commits
          {}
        end

        private

        def parse_commits(commits_string)
          {}.tap do |hsh|
            commits_string.each_line do |line|
              commit_code, commit_name = line.chomp.split("\t", 2)
              next if commit_code.nil? || commit_code.empty?

              hsh["#{commit_code} - #{commit_name}"] = commit_code
            end
          end
        end

        def hidden_branches(current, master)
          [].tap do |hb|
            hb.push('master', 'main') unless master
            hb.push(current_branch) unless current
          end.reject(&:empty?)
        end

        def formatted_branches
          bash.exec('git', 'for-each-ref', '--format=%(refname:short)', 'refs/heads/')
              .split("\n")
              .map(&:strip)
              .reject(&:empty?)
        end

        def bash
          BashCommand
        end
      end
    end
  end
end
