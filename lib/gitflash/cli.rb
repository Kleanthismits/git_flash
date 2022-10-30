# frozen_string_literal: true

require 'thor'

module Gitflash
  class Cli < Thor
    def self.exit_on_failure?
      true
    end

    desc 'checkout', 'Checkout the selected branch'
    long_desc <<-TEXT

    Presents a list with all the available local branches.

    You can use the arrow keys to navigate through the branches.
    Type for quick searching a specific branch.
    Press `enter` to choose and checkout the branch.
    Press `ctrl+c` to cancel the operation.
    TEXT

    def checkout
      branches? ? checkout_branch : prompt.ok('You only have one branch!')
    end

    desc 'delete', 'Delete the selected branches'
    long_desc <<-TEXT

    Presents a list with all the available local branches(without current or main/master).

    You can use the arrow keys to navigate through the branches.
    Type for quick searching a specific branch.
    Press `space` to choose multiple branches.
    Press `enter` to confirm selection and delete branches.
    Press `ctrl+c` to cancel the operation.

    WARNING: The branches will be deleted even if they have unmerged changes!!
    TEXT

    def delete
      branches? ? delete_branch : prompt.ok('You only have one branch!')
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

      prompt.warn(<<~TEXT
        You are about to permanently delete the following branches even if they have unmerged changes:

        #{selection.map { |br| "* #{br}" }.join("\n")}
      TEXT
                 )
      answer = prompt.yes?('Do you want to proceed?')
      puts answer ? git.delete(selection) : 'Exited'
    end

    def branches?
      all_branches && all_branches.size > 1
    end

    def prompt
      @prompt ||= Prompt.create
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

    def git
      Gitflash::Git::Wrapper
    end
  end
end
