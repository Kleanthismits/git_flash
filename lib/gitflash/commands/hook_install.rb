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

      # From the weakest protection to the strongest
      STRENGTH = %w[snapshot ask deny].freeze

      def call
        plan = build_plan
        data = settings.read(plan[:file])
        entry = settings.entry(data)
        add_mode(plan, entry)
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
        file = settings.path(scope)
        refuse_symlink!(file) unless scope == 'user'
        { scope: scope, file: file, marking_command: MARKING_COMMAND,
          applies_to: settings.applies_to(scope) }
      end

      # Without --mode the installed mode is kept, so running install again to add the
      # PostToolUse hook never turns ask or deny off. A weaker --mode needs --downgrade.
      def add_mode(plan, entry)
        previous = entry && installed_mode(entry['command'])
        mode = options[:mode] ? choice(:mode, Hook::Claude::MODES, 'snapshot') : previous
        mode ||= 'snapshot'
        refuse_downgrade!(previous, mode) if previous
        plan[:mode] = mode
        plan[:previous_mode] = previous if previous && previous != mode
        plan[:command] = hook_command(mode)
      end

      def installed_mode(command)
        command.to_s[/--mode[= ](\w+)/, 1] || 'snapshot'
      end

      def refuse_downgrade!(previous, mode)
        return if options[:downgrade] || STRENGTH.index(mode).to_i >= STRENGTH.index(previous).to_i

        usage_error!('invalid_options',
                     "The installed hook runs in #{previous} mode; --mode #{mode} would protect " \
                     'less. Pass --downgrade to change it anyway.')
      end

      # The repository decides what .claude holds, and a link there could point at the user's own
      # settings; writing through it would change a scope other than the one asked for. The
      # user scope may be a link (dotfiles) because the user owns it.
      def refuse_symlink!(file)
        linked = [file, File.dirname(file)].find { |path| File.symlink?(path) }
        return unless linked

        raise Error.new("#{linked} is a symbolic link; gitflash will not write settings through it",
                        code: 'invalid_settings')
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
                  text: "Installed the gitflash hook in #{plan[:file]} (#{mode_text(plan)}).\n" \
                        "It applies to #{plan[:applies_to]}, including running ones.")
      end

      def choice(name, allowed, default)
        value = options[name] || default
        return value if allowed.include?(value)

        usage_error!('invalid_options', "Unknown #{name} '#{value}' (use #{allowed.join(', ')})")
      end

      def hook_command(mode)
        mode == 'snapshot' ? 'gitflash hook claude' : "gitflash hook claude --mode #{mode}"
      end

      def mode_text(plan)
        changed = plan[:previous_mode] ? ", was #{plan[:previous_mode]}" : ''
        "#{plan[:mode]} mode#{changed}"
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
