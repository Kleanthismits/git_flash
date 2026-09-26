# frozen_string_literal: true

require 'fileutils'
require 'json'

module Gitflash
  module Commands
    # Registers `gitflash hook claude` as a Claude Code PreToolUse hook for Bash commands.
    # Merges into the settings file and keeps everything else in it.
    class HookInstall < Base
      SCOPES = %w[local project user].freeze
      HOOK_PATTERN = /\bgitflash hook claude\b/

      def call
        path = settings_path
        plan = { file: path, command: hook_command }
        settings = read(path)
        entry = find_entry(settings)
        return already_installed(plan) if entry && entry['command'] == plan[:command]
        return planned(plan, "Would add the gitflash hook to #{path}") if ui.dry_run?

        install(settings, entry, plan)
      end

      private

      def install(settings, entry, plan)
        entry ? entry['command'] = plan[:command] : add_entry(settings, plan[:command])
        write(plan[:file], settings)
        ui.report(status: 'done', plan: plan, result: plan,
                  text: "Installed the gitflash hook in #{plan[:file]}")
      end

      def choice(name, allowed, default)
        value = options[name] || default
        return value if allowed.include?(value)

        usage_error!('invalid_options', "Unknown #{name} '#{value}' (use #{allowed.join(', ')})")
      end

      def hook_command
        mode = choice(:mode, Hook::Claude::MODES, 'snapshot')
        mode == 'snapshot' ? 'gitflash hook claude' : "gitflash hook claude --mode #{mode}"
      end

      def settings_path
        case choice(:scope, SCOPES, 'local')
        when 'user' then File.join(Dir.home, '.claude', 'settings.json')
        when 'project' then File.join(repo.toplevel, '.claude', 'settings.json')
        else File.join(repo.toplevel, '.claude', 'settings.local.json')
        end
      end

      def already_installed(plan)
        ui.report(status: 'noop', plan: plan, result: plan,
                  text: "Already installed in #{plan[:file]}")
      end

      def read(path)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise Error.new("#{path} is not valid JSON: #{e.message}", code: 'invalid_settings')
      end

      def find_entry(settings)
        groups = Array(settings.dig('hooks', 'PreToolUse'))
        groups.flat_map { |group| Array(group['hooks']) }
              .find { |hook| hook['command'].to_s.match?(HOOK_PATTERN) }
      end

      def add_entry(settings, command)
        hooks = (settings['hooks'] ||= {})
        (hooks['PreToolUse'] ||= []) << {
          'matcher' => 'Bash',
          'hooks' => [{ 'type' => 'command', 'command' => command, 'timeout' => 30 }]
        }
      end

      def write(path, settings)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#{JSON.pretty_generate(settings)}\n")
      end
    end
  end
end
