# frozen_string_literal: true

require 'thor'

module Gitflash
  # `gitflash skill ...`: the Agent Skill that tells agents how to use gitflash
  class SkillCli < Thor
    include CommandRunner

    namespace 'skill'

    def self.exit_on_failure?
      true
    end

    desc 'install', 'Copy the gitflash Agent Skill into an agent skills directory'
    long_desc <<~TEXT
      Copies SKILL.md, which explains to agents when to use gitflash, the --json envelope, the
      plan then --yes flow and undo, into a skills directory:

      --scope user     ~/.claude/skills/gitflash/SKILL.md (default); every Claude Code session
      --scope project  .claude/skills/gitflash/SKILL.md at the repository top level, to commit
                       and share with your team
      --path DIR       DIR/gitflash/SKILL.md, for any agent that reads skills from DIR

      Does nothing when the installed skill is the one of this version. Run it again after
      upgrading gitflash. A file that differs may hold your own edits, which gitflash undo cannot
      bring back: replacing it needs --confirm TOKEN (the token the refusal names), or typing the
      token in a terminal.

      Accepts the global --json and --dry-run options after the subcommand: gitflash skill install --json
    TEXT
    option :scope, type: :string, enum: Commands::SkillInstall::SCOPES,
                   desc: 'user or project (default: user)'
    option :path, type: :string, banner: 'DIR', desc: 'Install into DIR/gitflash instead'
    def install
      run_command('skill install', Commands::SkillInstall,
                  repo_required: options[:scope] == 'project')
    end

    desc 'show', 'Print the gitflash Agent Skill'
    def show
      puts File.read(Commands::SkillInstall::SOURCE)
    end
  end
end
