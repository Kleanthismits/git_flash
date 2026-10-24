# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tempfile'

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

      # The mode the installed command runs in, read the way a shell splits it: `snapshot` when
      # it has no --mode; a --mode gitflash does not know is refused, never read as snapshot,
      # so a reinstall cannot quietly weaken it
      def installed_mode(command)
        words = Shellwords.split(command.to_s)
        index = words.index { |word| word == '--mode' || word.start_with?('--mode=') }
        return 'snapshot' unless index

        mode = words[index] == '--mode' ? words[index + 1] : words[index].delete_prefix('--mode=')
        return mode if Hook::Claude::MODES.include?(mode)

        raise Error.new("The installed hook command `#{command}` has a mode gitflash cannot " \
                        'read; fix or remove it, then install again', code: 'invalid_settings')
      rescue ArgumentError
        raise Error.new("The installed hook command `#{command}` cannot be parsed",
                        code: 'invalid_settings')
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
        write_atomically(plan[:file], "#{JSON.pretty_generate(data)}\n")
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

      # Writes a temporary file next to the settings and renames it into place, so a crash never
      # leaves half a file: Claude Code ignores a settings file it cannot parse, and with it the
      # user's own permission rules. A linked user settings file (dotfiles) is written where the
      # link points, keeping the link; the file keeps its permissions.
      def write_atomically(path, text)
        path = File.realpath(path) if File.symlink?(path)
        FileUtils.mkdir_p(File.dirname(path))
        file = Tempfile.create(['.gitflash-settings', '.json'], File.dirname(path))
        replace(file, path, text)
      rescue SystemCallError, IOError => e
        raise Error.new("Could not write #{path}: #{e.message}", code: 'invalid_settings')
      end

      def replace(file, path, text)
        file.write(text)
        file.flush
        file.fsync
        file.close
        File.chmod(File.stat(path).mode & 0o7777, file.path) if File.exist?(path)
        File.rename(file.path, path)
      ensure
        FileUtils.rm_f(file.path) if file && File.exist?(file.path)
      end

      def add_entry(data, event, command)
        hooks = (data['hooks'] ||= {})
        groups = hooks.is_a?(Hash) ? (hooks[event] ||= []) : nil
        unless groups.is_a?(Array)
          raise Error.new('The settings file has a `hooks` value gitflash cannot add to ' \
                          "(#{event} must be a list)", code: 'invalid_settings')
        end

        groups << {
          'matcher' => 'Bash',
          'hooks' => [{ 'type' => 'command', 'command' => command, 'timeout' => 30 }]
        }
      end
    end
  end
end
