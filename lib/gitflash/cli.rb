# frozen_string_literal: true

require 'thor'
require 'pry'

module Gitflash
  class Cli < Thor
    extend Configuration::Descriptions

    def self.exit_on_failure?
      true
    end

    desc 'checkout', descriptions.checkout.short
    long_desc descriptions.checkout.long

    def checkout
      branches? ? checkout_branch : prompt.ok('You only have one branch!')
    end

    desc 'delete', descriptions.delete.short
    long_desc descriptions.delete.long

    def delete
      branches? ? delete_branch : prompt.ok('You only have one branch!')
    end

    desc 'reset', descriptions.reset.short
    long_desc descriptions.reset.long

    option :hard, type: :boolean, default: false, desc: 'Perform a hard reset'
    def reset
      commits? ? reset_to_commit : prompt.ok('You only have one branch!')
    end

    private

    def checkout_branch
      selection = prompt.select(
        'Select a branch to checkout',
        branches,
        **checkout_options
      )

      git.checkout(selection)
    end

    def delete_branch
      selection = prompt.multi_select(
        'Select branches to delete',
        branches(options: { master: false, current: false })
      )

      warning_message = <<~TEXT
        You are about to permanently delete the following branches even if they have unmerged changes:

        #{selection.map { |br| "* #{br}" }.join("\n")}
      TEXT

      prompt_proceed_warning(warning_message) { git.delete(selection) }
    end

    def reset_to_commit
      selection = prompt.select('Select a commit to reset to', branch_commits)
      reset_options = { commit_hash: selection, hard: options[:hard] }

      if options[:hard]
        warning_message = 'You are about to reset your branch and lose all your current changes'
        prompt.proceed_with_warning(warning_message) { git.reset(**reset_options) }
      else
        git.reset(**reset_options)
      end
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

    def prompt_proceed_warning(message)
      prompt.warn(message)
      answer = prompt.yes?('Do you want to proceed?')
      puts answer ? yield : 'Exited'
    end

    def checkout_options
      {}.tap do |opt|
        opt[:default] = current unless current.nil?
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
      @branch_commits = git.branch_commits
    end

    def git
      Gitflash::Git::Wrapper
    end
  end
end
