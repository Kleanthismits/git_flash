# frozen_string_literal: true

require 'thor'

module Gitflash
  class Cli < Thor
    extend Configuration::Descriptions

    def self.exit_on_failure?
      true
    end

    desc 'checkout', descriptions.checkout.short
    long_desc descriptions.checkout.long

    def checkout
      ensure_git_repo!
      branches? ? checkout_branch : prompt.ok('You only have one branch!')
    end

    desc 'delete', descriptions.delete.short
    long_desc descriptions.delete.long

    def delete
      ensure_git_repo!
      branches? ? delete_branch : prompt.ok('You only have one branch!')
    end

    desc 'reset', descriptions.reset.short
    long_desc descriptions.reset.long

    option :hard, type: :boolean, default: false, desc: 'Perform a hard reset'
    def reset
      ensure_git_repo!
      commits? ? reset_to_commit : prompt.ok('You only have one commit!')
    end

    desc 'version', 'Print the gitflash version'
    map %w[--version -v] => :version

    def version
      puts VERSION
    end

    private

    def checkout_branch
      selection = prompt.select(
        'Select a branch to checkout',
        branches,
        **checkout_options
      )

      run_git('checkout') { git.checkout(selection) }
    end

    def delete_branch
      choices = branches(options: { master: false, current: false })
      return prompt.ok('No branches available to delete') if choices.empty?

      selection = prompt.multi_select('Select branches to delete', choices)
      return prompt.ok('No branches selected') if selection.empty?

      warning_message = <<~TEXT
        You are about to permanently delete the following branches even if they have unmerged changes:

        #{selection.map { |br| "* #{br}" }.join("\n")}
      TEXT

      proceed_with_warning(warning_message) do
        run_git('delete') { git.delete(selection) }
      end
    end

    def reset_to_commit
      selection = prompt.select('Select a commit to reset to', branch_commits)
      reset_options = { commit_hash: selection, hard: options[:hard] }

      if options[:hard]
        warning_message = 'You are about to reset your branch and lose all your current changes'
        proceed_with_warning(warning_message) { run_git('reset') { git.reset(**reset_options) } }
      else
        run_git('reset') { git.reset(**reset_options) }
      end
    end

    def proceed_with_warning(message, &)
      result = prompt.proceed_with_warning(message, &)
      puts result if result == 'Exited'
    end

    def run_git(command)
      raise Thor::Error, "git #{command} failed" unless yield
    end

    def ensure_git_repo!
      git.inside_work_tree!
    rescue Git::CommandError
      raise Thor::Error, 'Not a git repository'
    end

    def branches?
      all_branches && all_branches.size > 1
    end

    def commits?
      branch_commits && branch_commits.size > 1
    end

    def prompt
      @prompt ||= Prompt.create
    end

    def checkout_options
      {}.tap do |opt|
        opt[:default] = current unless current.to_s.empty?
      end
    end

    def branches(options: {})
      git.local_branches(**options)
    end

    def all_branches
      @all_branches ||= git.all_local_branches
    end

    def current
      @current ||= git.current_branch
    end

    def branch_commits
      @branch_commits ||= git.branch_commits
    end

    def git
      Gitflash::Git::Wrapper
    end
  end
end
