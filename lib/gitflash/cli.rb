# frozen_string_literal: true

require 'thor'
require 'gitflash/prompt'
require 'gitflash/git_wrapper'
require 'pry'

module GitFlash
  class Cli < Thor
    desc 'checkout', 'Checkout the selected branch'
    long_desc <<-TEXT

    Presents a list with all the available local branches.

    You can use the arrow keys to navigate through the branches.
    Press `enter` to choose and checkout the branch.
    Press `ctrl+c` to cancel the operation.
    TEXT

    def checkout
      has_branches? ? checkout_branch : prompt.ok('You only have one branch!')
    end

    desc 'delete', 'Delete the selected branches'
    long_desc <<-TEXT

    Presents a list with all the available local branches(without current or main/master).

    You can use the arrow keys to navigate through the branches.
    Press `space` to choose multiple branches.
    Press `enter` to confirm selection and delete branches.
    Press `ctrl+c` to cancel the operation.

    WARNING: The branches will be deleted even if they have unmerged changes!!
    TEXT

    def delete
      has_branches? ? delete_branch : prompt.ok('You only have one branch!')
    end

    private

    def checkout_branch
      selection = prompt.select(
        'Select a branch to checkout',
        branches,
        **checkout_options
      )

      GitWrapper.checkout(selection)
    end

    def delete_branch
      selection = prompt.multi_select(
        'Select branches to delete',
        branches(options: { master: false, current: false }),
      )

      prompt.warn(<<~TEXT
        You are about to permanently delete the following branches even if they have unmerged changes:

        #{selection.map { |br| "* #{br}" }.join("\n")}
      TEXT
                 )
      answer = prompt.yes?('Do you want to proceed?')
      response = GitWrapper.delete(selection)
      puts response
    end

    def has_branches?
      branches && !branches.empty?
    end

    def prompt
      @prompt ||= Prompt.create
    end

    def checkout_options
      {}.tap do |opt|
        opt[:default] = current if current && !current.empty?
      end
    end

    def branches(options: {})
      @branches ||= GitWrapper.get_local_branches(**options)
    end

    def current
      GitWrapper.current_branch
    end
  end
end
