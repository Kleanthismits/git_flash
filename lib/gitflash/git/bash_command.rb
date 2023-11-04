# frozen_string_literal: true

module Gitflash
  module Git
    class BashCommand
      class << self
        def exec(command)
          `#{command}`
        end

        def system_exec(*args)
          system(*args)
        end
      end
    end
  end
end
