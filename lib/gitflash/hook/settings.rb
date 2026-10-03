# frozen_string_literal: true

require 'json'

module Gitflash
  module Hook
    # Where Claude Code reads the settings that can hold the gitflash hook, following its rules:
    #   local    .claude/settings.local.json at the repository root (the main checkout's root
    #            inside a linked worktree), for sessions started anywhere in the repository
    #   project  .claude/settings.json in the directory a session starts in; gitflash uses the
    #            repository's top level, so it applies to sessions started there
    #   user     ~/.claude/settings.json, for every session
    # Claude Code reloads these files in running sessions, so no restart is needed.
    class Settings
      SCOPES = %w[local project user].freeze
      PATTERN = /\bgitflash hook claude\b/

      # `repo` is nil outside a git repository; only the user scope applies there
      def initialize(repo)
        @repo = repo
      end

      def path(scope)
        case scope
        when 'user' then File.join(Dir.home, '.claude', 'settings.json')
        when 'project' then File.join(@repo.toplevel, '.claude', 'settings.json')
        else File.join(@repo.main_root, '.claude', 'settings.local.json')
        end
      end

      # Which Claude Code sessions read the file of a scope
      def applies_to(scope)
        case scope
        when 'user' then 'every Claude Code session'
        when 'project' then "Claude Code sessions started in #{@repo.toplevel}"
        else "Claude Code sessions in #{@repo.main_root} and its worktrees"
        end
      end

      def scopes
        @repo ? SCOPES : %w[user]
      end

      def read(path)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise Error.new("#{path} is not valid JSON: #{e.message}", code: 'invalid_settings')
      end

      # The gitflash hook entry in parsed settings, or nil
      def entry(settings)
        groups = Array(settings.dig('hooks', 'PreToolUse'))
        groups.flat_map { |group| Array(group['hooks']) }
              .find { |hook| hook['command'].to_s.match?(PATTERN) }
      end
    end
  end
end
