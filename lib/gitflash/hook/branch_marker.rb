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

        FileUtils.mkdir_p(@state_dir, mode: 0o700)
        prune_records
        existing = creations.select { |creation| branch_exists?(creation[:dir], creation[:branch]) }
        File.write(path, JSON.generate(existing.map { |creation| key(creation) }))
      end

      # PostToolUse: branch names marked as agent work, in the directories the command ran in
      def call(command, cwd, tool_use_id = nil)
        existed = take_record(tool_use_id)
        created = CommandParser.new(cwd).creations(command)
        created.reject { |creation| existed.include?(key(creation)) }
               .select { |creation| mark(creation[:dir], creation[:branch]) }
               .map { |creation| creation[:branch] }.uniq
      end

      private

      def key(creation)
        "#{creation[:dir]}\0#{creation[:branch]}"
      end

      # One file per tool call, named from a hash so the id can never form a path
      def record_path(tool_use_id)
        return nil if tool_use_id.to_s.empty?

        File.join(@state_dir, "#{Digest::SHA256.hexdigest(tool_use_id.to_s)}.json")
      end

      def take_record(tool_use_id)
        path = record_path(tool_use_id)
        return [] unless path && File.file?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        []
      ensure
        FileUtils.rm_f(path) if path
      end

      def prune_records
        Dir.glob(File.join(@state_dir, '*.json')).each do |file|
          FileUtils.rm_f(file) if @clock.call - File.mtime(file) > STALE_RECORD_SECONDS
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
