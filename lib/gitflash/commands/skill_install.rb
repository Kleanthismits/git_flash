# frozen_string_literal: true

require 'digest'

module Gitflash
  module Commands
    # Copies the gitflash Agent Skill that ships in the gem (skills/gitflash/SKILL.md) into an
    # agent's skills directory:
    #   user     ~/.claude/skills/gitflash/SKILL.md, for every Claude Code session (default)
    #   project  .claude/skills/gitflash/SKILL.md at the repository top level, shared with the team
    #   --path   DIR/gitflash/SKILL.md, for any agent that reads skills from DIR
    # A file that differs from the shipped one may hold the user's own edits, which no snapshot
    # saves, so replacing it needs --confirm TOKEN instead of --yes.
    class SkillInstall < Base
      SOURCE = File.expand_path('../../../skills/gitflash/SKILL.md', __dir__)
      SCOPES = %w[user project].freeze
      NAME = 'gitflash'

      def call
        plan = build_plan
        existing = read_existing(plan[:file])
        return already_installed(plan) if existing == skill
        return replace(plan, existing) if existing
        return planned(plan, "Would install #{where(plan)}") if ui.dry_run?

        install(plan, 'install')
      end

      private

      def replace(plan, existing)
        # In the plan, so the --confirm token belongs to these file contents
        plan[:previous_sha256] = Digest::SHA256.hexdigest(existing)
        return planned(plan, "Would update #{where(plan)}") if ui.dry_run?
        return cancelled(plan) unless confirm_replace?(plan)

        install(plan, 'update')
      end

      def install(plan, verb)
        write(plan[:file])
        ui.report(status: 'done', plan: plan, result: plan,
                  text: "#{verb.capitalize}d #{where(plan)}")
      end

      def where(plan) = "the gitflash skill at #{shown(plan[:file])}"

      def build_plan
        scope, directory = target
        { scope: scope, directory: directory, file: File.join(directory, NAME, 'SKILL.md'),
          version: VERSION }
      end

      # The scope and the skills directory the skill goes into
      def target
        return path_target if options[:path]

        scope = options[:scope] || 'user'
        unless SCOPES.include?(scope)
          usage_error!('invalid_options', "Unknown scope '#{scope}' (use #{SCOPES.join(', ')})")
        end
        return ['user', File.join(Dir.home, '.claude', 'skills')] if scope == 'user'

        directory = File.join(repo.toplevel, '.claude', 'skills')
        refuse_symlinks!(directory)
        ['project', directory]
      end

      def path_target
        usage_error!('invalid_options', 'Pass --scope or --path, not both') if options[:scope]

        directory = File.expand_path(options[:path])
        return ['path', directory] if File.directory?(directory)

        usage_error!('invalid_options', "#{shown(directory)} is not a directory")
      end

      # The repository decides what .claude holds, and a link there could point at the user's own
      # skills; writing through it would change files outside the repository
      def refuse_symlinks!(directory)
        paths = [File.dirname(directory), directory, File.join(directory, NAME),
                 File.join(directory, NAME, 'SKILL.md')]
        linked = paths.find { |path| File.symlink?(path) }
        return unless linked

        raise Error, "#{shown(linked)} is a symbolic link; gitflash will not write the skill " \
                     'through it'
      end

      def read_existing(file)
        File.exist?(file) ? File.read(file) : nil
      rescue SystemCallError => e
        raise Error, "Could not read #{shown(file)}: #{e.message}"
      end

      def confirm_replace?(plan)
        summary = "#{shown(plan[:file])} differs from the gitflash #{VERSION} skill; " \
                  'replacing it loses any edits made to it'
        ui.confirm?(summary, plan: plan, irreversible: true)
      end

      def write(file)
        AtomicFile.write(file, skill)
      rescue SystemCallError, IOError => e
        raise Error, "Could not write #{shown(file)}: #{e.message}"
      end

      def already_installed(plan)
        ui.report(status: 'noop', plan: plan, result: plan,
                  text: "The gitflash #{VERSION} skill is already at #{shown(plan[:file])}")
      end

      def skill
        @skill ||= File.read(SOURCE)
      end
    end
  end
end
