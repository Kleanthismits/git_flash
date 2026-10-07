# frozen_string_literal: true

module Gitflash
  module Commands
    # Shows whether the gitflash hook protects Claude Code sessions in the current directory:
    # which settings files hold it, which sessions each file applies to, and whether the
    # gitflash executable the hook runs can be found.
    class HookStatus < Base
      def call
        settings = Hook::Settings.new(inside_repo? ? repo : nil)
        files = settings.scopes.map { |scope| file_status(settings, scope) }
        result = summary(files, find_executable)
        ui.report(status: 'done', result: result, text: text(result))
      end

      private

      def inside_repo?
        repo.ensure_work_tree!
        true
      rescue Error
        false
      end

      def summary(files, executable)
        installed = files.select { |file| file[:installed] }
        active = executable && installed.any?
        { active: active ? true : false, marking: active && installed.any? { |f| f[:marking] },
          executable: executable, files: files }
      end

      def file_status(settings, scope)
        path = settings.path(scope)
        data = settings.read(path)
        entry = settings.entry(data)
        { scope: scope, file: path, installed: !entry.nil?, command: entry&.fetch('command', nil),
          marking: !settings.entry(data, Hook::Claude::POST_EVENT).nil?,
          applies_to: settings.applies_to(scope) }
      end

      def find_executable
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, 'gitflash') }
           .find { |path| File.file?(path) && File.executable?(path) }
      end

      def text(result)
        lines = [headline(result)]
        result[:files].each do |file|
          state = file[:installed] ? installed_text(file) : 'not installed'
          lines << "  #{file[:scope].ljust(8)} #{file[:file]}: #{state}"
          lines << "           applies to #{file[:applies_to]}" if file[:installed]
        end
        lines << "  gitflash executable: #{result[:executable] || 'not found on PATH'}"
        lines.join("\n")
      end

      def installed_text(file)
        note = file[:marking] ? ', marks agent branches' : ', branch marking off'
        "installed (#{file[:command]})#{note}"
      end

      def headline(result)
        return active_headline(result) if result[:active]

        reason = if result[:executable]
                   'run `gitflash hook install`'
                 else
                   'the gitflash executable is not on PATH'
                 end
        "gitflash hook: not active (#{reason})"
      end

      def active_headline(result)
        return 'gitflash hook: active, marks agent branches' if result[:marking]

        'gitflash hook: active (branch marking off: run `gitflash hook install` again)'
      end
    end
  end
end
