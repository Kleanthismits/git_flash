# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

module Gitflash
  module Hook
    # Marks the branches an agent just created as agent work (see Ownership), so
    # `gitflash clean --agent` can find them. Runs in the PostToolUse hook, after the command:
    # the branch exists then, and Claude Code only runs it when the command succeeded.
    #
    # Text in a command proves nothing (`false && git branch x` creates nothing), so a branch is
    # only marked when it is new:
    # - the PreToolUse hook records which of the branches the command names exist before it runs
    #   (`record`), and a branch that existed then is never marked;
    # - its reflog must say it was created a moment ago ("branch: Created from ..."), which also
    #   covers a Claude Code that ran no PreToolUse hook;
    # - it must be unmarked.
    class BranchMarker
      CREATED = 'branch: Created from'
      RECENT_SECONDS = 120
      STALE_RECORD_SECONDS = 24 * 60 * 60

      def initialize(clock: -> { Time.now }, state_dir: nil)
        @clock = clock
        @state_dir = state_dir || File.join(Dir.tmpdir, "gitflash-hook-#{Process.uid}")
      end

      # PreToolUse: remember the branches the command may create that exist already
      def record(command, cwd, tool_use_id)
        creations = CommandParser.new(cwd).creations(command)
        return if creations.empty? || (path = record_path(tool_use_id)).nil?
        return unless private_state_dir?

        prune_records
        File.write(path, JSON.generate(existing_stamps(creations)))
      end

      # PostToolUse: branch names marked as agent work, in the directories the command ran in
      def call(command, cwd, tool_use_id = nil)
        existed = take_record(tool_use_id)
        created = CommandParser.new(cwd).creations(command)
        created.reject { |creation| already_there?(existed, creation) }
               .select { |creation| mark(creation[:dir], creation[:branch]) }
               .map { |creation| creation[:branch] }.uniq
      end

      private

      # { key => stamp } of the named branches that exist now
      def existing_stamps(creations)
        existing = creations.select { |creation| branch_exists?(creation[:dir], creation[:branch]) }
        existing.to_h { |creation| [key(creation), stamp(creation)] }
      end

      def key(creation)
        "#{creation[:dir]}\0#{creation[:branch]}"
      end

      # A branch that was there before the command and is the same branch now. One that the
      # command deleted and created again has a new reflog, so a new stamp, and counts as new.
      # An empty stamp (no reflog) is no evidence of a new branch either: all that is known is
      # that the branch existed, and claiming a branch a person may have made is the worse
      # mistake, so it is left alone. Without a reflog nothing could be marked in any case.
      def already_there?(existed, creation)
        existed.key?(key(creation)) && existed[key(creation)] == stamp(creation)
      end

      # Time, commit and message of the oldest reflog entry, which is the creation of the branch;
      # empty when the reflog is off
      def stamp(creation)
        return '' unless Dir.exist?(creation[:dir])

        stdout, _stderr, success = Git::BashCommand.capture(
          'git', '-C', creation[:dir], 'log', '-g', '--format=%ct %H %gs',
          "#{Repo::HEADS}#{creation[:branch]}", '--'
        )
        success ? stdout.lines(chomp: true).last.to_s : ''
      end

      # One file per tool call, named from a hash so the id can never form a path
      def record_path(tool_use_id)
        return nil if tool_use_id.to_s.empty?

        File.join(@state_dir, "#{Digest::SHA256.hexdigest(tool_use_id.to_s)}.json")
      end

      def take_record(tool_use_id)
        path = record_path(tool_use_id)
        return {} unless path && private_state_dir? && File.file?(path)

        record = JSON.parse(File.read(path))
        record.is_a?(Hash) ? record : {}
      rescue JSON::ParserError
        {}
      ensure
        FileUtils.rm_f(path) if path
      end

      # The directory holds the records of this user only: created with mode 0700, and refused
      # when it is a link, belongs to someone else or is open to the group or others (a shared
      # /tmp lets another user create the name first)
      def private_state_dir?
        FileUtils.mkdir_p(@state_dir, mode: 0o700)
        stat = File.lstat(@state_dir)
        stat.directory? && stat.owned? && stat.mode.nobits?(0o077)
      rescue SystemCallError
        false
      end

      # Another hook may delete a record at the same moment: a vanished file is not an error
      def prune_records
        Dir.glob(File.join(@state_dir, '*.json')).each do |file|
          FileUtils.rm_f(file) if @clock.call - File.mtime(file) > STALE_RECORD_SECONDS
        rescue SystemCallError
          next
        end
      end

      def branch_exists?(dir, branch)
        return false unless Dir.exist?(dir)

        _stdout, _stderr, success = Git::BashCommand.capture(
          'git', '-C', dir, 'show-ref', '--verify', '--quiet', "#{Repo::HEADS}#{branch}"
        )
        success
      end

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
