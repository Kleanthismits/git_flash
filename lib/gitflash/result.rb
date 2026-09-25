# frozen_string_literal: true

module Gitflash
  # Outcome of a git command that changes the repository
  Result = Data.define(:success, :output) do
    alias_method :success?, :success
  end
end
