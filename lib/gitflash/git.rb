# frozen_string_literal: true

module GitFlash
  # A class that exposes git native methods as ruby methods
  class Git
    class << self
      def branch
        `git branch`
      end

      def checkout(branch)
        `git checkout #{branch}`
      end

      def current_branch
        `git branch | grep '\''^\*'\'' | cut -d'\'' '\'' -f2 | tr -d '\''\n'\'' `
      end
    end
  end
end
