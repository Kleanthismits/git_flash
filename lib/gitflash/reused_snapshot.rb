# frozen_string_literal: true

require 'delegate'

module Gitflash
  # A snapshot `Snapshots#create` handed back because the state had not changed since it was
  # taken. Output says so, so its older id is not mistaken for a missing snapshot.
  class ReusedSnapshot < SimpleDelegator
    def reused? = true
  end
end
