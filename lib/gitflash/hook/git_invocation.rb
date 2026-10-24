# frozen_string_literal: true

require 'shellwords'

module Gitflash
  module Hook
    # Reads `git [global options] SUBCOMMAND ARGS` the way git does: `-C`, `--git-dir`,
    # `--work-tree` and `GIT_DIR` / `GIT_WORK_TREE` decide the repository, and an alias (from
    # `-c alias.NAME=...` or the repository's config) is replaced by what it stands for.
    class GitInvocation
      # dir: the work tree git uses; script: the shell command of a `!` alias, else nil
      Parsed = Data.define(:dir, :subcommand, :args, :script)

      VALUE_OPTIONS = %w[-C -c --git-dir --work-tree --namespace --exec-path --config-env
                         --super-prefix].freeze
      DIR_OPTIONS = { '-C' => :dir, '--git-dir' => :git_dir, '--work-tree' => :work_tree }.freeze

      # Aliases from `git config` in the directory, as { name => value }; none when it is not a
      # repository
      def self.configured_aliases(dir)
        stdout, _stderr, success = Git::BashCommand.capture('git', '-C', dir, 'config', '-z',
                                                            '--get-regexp', '^alias\\.')
        return {} unless success

        stdout.split("\0").to_h do |entry|
          key, value = entry.split("\n", 2)
          [key.delete_prefix('alias.'), value.to_s]
        end
      end

      # `dir_after` resolves a path against a directory (CommandParser's rules for paths the
      # shell decides); `aliases` returns the configured aliases of a directory
      def initialize(dir_after:, aliases:)
        @dir_after = dir_after
        @aliases = aliases
      end

      def parse(words, dir, env = {})
        index, options = read_options(words, { dir: dir, aliases: {} })
        dir = repository_dir(options, env)
        subcommand = words[index]
        args = words[(index + 1)..] || []
        expansion = alias_for(subcommand, options[:aliases], dir)
        expansion ? expand(expansion, args, dir) : Parsed.new(dir:, subcommand:, args:, script: nil)
      end

      private

      # Index of the subcommand, and what the global options say
      def read_options(words, options)
        index = 1
        while (option = words[index])&.start_with?('-')
          name, value = option.split('=', 2)
          takes_next = value.nil? && VALUE_OPTIONS.include?(name)
          apply(options, name, takes_next ? words[index + 1].to_s : value.to_s)
          index += takes_next ? 2 : 1
        end
        [index, options]
      end

      def apply(options, name, value)
        if (key = DIR_OPTIONS[name])
          options[key] = @dir_after.call(value, options[:dir])
        elsif name == '-c' && value.start_with?('alias.')
          alias_name, expansion = value.delete_prefix('alias.').split('=', 2)
          options[:aliases][alias_name] = expansion.to_s
        end
      end

      # The work tree git uses: --work-tree or GIT_WORK_TREE, else the one --git-dir or GIT_DIR
      # belongs to, else the directory after -C
      def repository_dir(options, env)
        work_tree = options[:work_tree] || from_env(env, 'GIT_WORK_TREE', options)
        return work_tree if work_tree

        git_dir = options[:git_dir] || from_env(env, 'GIT_DIR', options)
        return options[:dir] unless git_dir

        File.basename(git_dir) == '.git' ? File.dirname(git_dir) : git_dir
      end

      def from_env(env, name, options)
        env[name] && @dir_after.call(env[name], options[:dir])
      end

      # Git never lets an alias replace a built-in command
      def alias_for(subcommand, inline, dir)
        return nil if subcommand.nil? || CommandParser::BUILTINS.include?(subcommand)

        inline[subcommand] || @aliases.call(dir)[subcommand]
      end

      # `!cmd` aliases run in the shell; others are git arguments
      def expand(expansion, args, dir)
        if expansion.start_with?('!')
          script = [expansion.delete_prefix('!'), *args].join(' ')
          return Parsed.new(dir:, subcommand: nil, args: [], script:)
        end

        words = Shellwords.split(expansion) + args
        Parsed.new(dir:, subcommand: words.first, args: words.drop(1), script: nil)
      rescue ArgumentError
        Parsed.new(dir:, subcommand: nil, args: [], script: nil)
      end
    end
  end
end
