# frozen_string_literal: true

require 'fileutils'

module Gitflash
  module Commands
    # Registers `gitflash hook claude` as a Claude Code PreToolUse hook for Bash commands.
    # Merges into the settings file and keeps everything else in it.
    class HookInstall < Base
      SCOPES = Hook::Settings::SCOPES

      def call
        plan = build_plan
        data = settings.read(plan[:file])
        entry = settings.entry(data)
        return already_installed(plan) if entry && entry['command'] == plan[:command]
        return planned(plan, "Would add the gitflash hook to #{plan[:file]}") if ui.dry_run?

        install(data, entry, plan)
      end

      private

      def build_plan
        scope = choice(:scope, SCOPES, 'local')
        { scope: scope, file: settings.path(scope), command: hook_command,
          applies_to: settings.applies_to(scope) }
      end

      def settings
        @settings ||= Hook::Settings.new(options[:scope] == 'user' ? nil : repo)
      end

      def install(data, entry, plan)
        entry ? entry['command'] = plan[:command] : add_entry(data, plan[:command])
        FileUtils.mkdir_p(File.dirname(plan[:file]))
        File.write(plan[:file], "#{JSON.pretty_generate(data)}\n")
        ui.report(status: 'done', plan: plan, result: plan,
                  text: "Installed the gitflash hook in #{plan[:file]}.\n" \
                        "It applies to #{plan[:applies_to]}, including running ones.")
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

      def already_installed(plan)
        ui.report(status: 'noop', plan: plan, result: plan,
                  text: "Already installed in #{plan[:file]}.\nIt applies to #{plan[:applies_to]}.")
      end

      def add_entry(data, command)
        hooks = (data['hooks'] ||= {})
        (hooks['PreToolUse'] ||= []) << {
          'matcher' => 'Bash',
          'hooks' => [{ 'type' => 'command', 'command' => command, 'timeout' => 30 }]
        }
      end
    end
  end
end
