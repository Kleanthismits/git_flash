# frozen_string_literal: true

require 'fileutils'

module Gitflash
  module Commands
    # Registers `gitflash hook claude` as a Claude Code hook for Bash commands: PreToolUse
    # (snapshots before destructive git commands) and PostToolUse (marks branches an agent
    # created). Merges into the settings file and keeps everything else in it.
    class HookInstall < Base
      SCOPES = Hook::Settings::SCOPES
      MARKING_COMMAND = 'gitflash hook claude'

      def call
        plan = build_plan
        data = settings.read(plan[:file])
        entry = settings.entry(data)
        marking = settings.entry(data, Hook::Claude::POST_EVENT)
        return already_installed(plan) if up_to_date?(entry, marking, plan)
        return planned(plan, "Would add the gitflash hook to #{plan[:file]}") if ui.dry_run?

        install(data, entry, marking, plan)
      end

      private

      def up_to_date?(entry, marking, plan)
        entry && entry['command'] == plan[:command] && marking
      end

      def build_plan
        scope = choice(:scope, SCOPES, 'local')
        { scope: scope, file: settings.path(scope), command: hook_command,
          marking_command: MARKING_COMMAND, applies_to: settings.applies_to(scope) }
      end

      def settings
        @settings ||= Hook::Settings.new(options[:scope] == 'user' ? nil : repo)
      end

      def install(data, entry, marking, plan)
        entry ? entry['command'] = plan[:command] : add_entry(data, 'PreToolUse', plan[:command])
        add_entry(data, Hook::Claude::POST_EVENT, MARKING_COMMAND) unless marking
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

      def add_entry(data, event, command)
        hooks = (data['hooks'] ||= {})
        (hooks[event] ||= []) << {
          'matcher' => 'Bash',
          'hooks' => [{ 'type' => 'command', 'command' => command, 'timeout' => 30 }]
        }
      end
    end
  end
end
