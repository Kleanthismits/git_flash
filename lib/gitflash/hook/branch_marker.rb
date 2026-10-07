# frozen_string_literal: true

module Gitflash
  module Hook
    # Marks the branches an agent just created as agent work (see Ownership), so
    # `gitflash clean --agent` can find them. Runs in the PostToolUse hook, after the command:
    # the branch exists then, and Claude Code only runs it when the command succeeded.
    #
    # A branch is marked only when it is unmarked and its reflog says it was created a moment
    # ago ("branch: Created from ..."), so a branch that was already there is never claimed.
    class BranchMarker
      CREATED = 'branch: Created from'
      RECENT_SECONDS = 120

      def initialize(clock: -> { Time.now })
        @clock = clock
      end

      # Branch names marked as agent work, in the directories the command ran in
      def call(command, cwd)
        created = CommandParser.new(cwd).creations(command)
        created.select { |creation| mark(creation[:dir], creation[:branch]) }
               .map { |creation| creation[:branch] }.uniq
      end

      private

      def mark(dir, branch)
        return false unless Dir.exist?(dir)

        Dir.chdir(dir) do
          ownership = Ownership.new
          next false unless created_recently?(branch) && !ownership.all.key?(branch)

          ownership.mark(branch, 'agent')
          true
        end
      end

      # The oldest reflog entry of the branch is its creation, and it is recent
      def created_recently?(branch)
        stdout, _stderr, success = Git::BashCommand.capture(
          'git', 'log', '-g', '--format=%ct%x1f%gs', "#{Repo::HEADS}#{branch}", '--'
        )
        return false unless success

        created, subject = stdout.lines(chomp: true).last.to_s.split("\x1f", 2)
        subject.to_s.start_with?(CREATED) && @clock.call.to_i - created.to_i <= RECENT_SECONDS
      end
    end
  end
end
