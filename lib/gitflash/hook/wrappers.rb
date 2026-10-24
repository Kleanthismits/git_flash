# frozen_string_literal: true

module Gitflash
  module Hook
    # Commands that run the command after them: `sudo -u me git ...`, `timeout 5 git ...`,
    # `xargs git ...`. Strips them, with their options, so the parser sees the git command.
    module Wrappers
      # Wrapper => its options that take a value as the next word
      OPTIONS = {
        'sudo' => %w[-u -g -h -p -C -D -r -t -U -T --user --group --host --prompt --chdir],
        'env' => %w[-u -C -S --unset --chdir --split-string],
        'command' => [], 'exec' => %w[-a], 'time' => %w[-f -o --format --output],
        'nohup' => [], 'nice' => %w[-n --adjustment], 'ionice' => %w[-c -n -p -P -u],
        'stdbuf' => %w[-i -o -e], 'chronic' => [], 'caffeinate' => %w[-t -w],
        'timeout' => %w[-k -s --kill-after --signal],
        # -i, -l and -e take only an attached value (`-i{}`), so they are not listed
        'xargs' => %w[-I -n -P -L -d -E -s -a --arg-file --delimiter --max-args --max-procs]
      }.freeze
      # Wrappers whose first word after the options is not the command (`timeout 5 git ...`)
      LEADING_ARGUMENT = %w[timeout].freeze
      CHDIR_OPTIONS = %w[-C -D --chdir].freeze
      FIND_EXEC = %w[-exec -execdir -ok -okdir].freeze
      FIND_END = [';', '\;', '+'].freeze

      module_function

      # The words without leading wrappers and their options, and the directory `sudo -D` or
      # `env -C` switch to (nil when none does)
      def strip(words)
        chdir = nil
        while (options = OPTIONS[File.basename(words.first.to_s)])
          name = File.basename(words.first)
          words, dir = drop_options(words.drop(1), options)
          chdir = dir || chdir
          words = words.drop(1) if LEADING_ARGUMENT.include?(name)
        end
        [words, chdir]
      end

      # Drops options (and the values of those that take one) up to the command
      def drop_options(words, with_value)
        chdir = nil
        while (word = words.first)&.start_with?('-')
          words = words.drop(1)
          break if word == '--'
          next unless with_value.include?(word)

          chdir = words.first if CHDIR_OPTIONS.include?(word)
          words = words.drop(1)
        end
        [words, chdir]
      end

      # The command `find ... -exec CMD ... ;` runs, or nil
      def find_exec(words)
        return nil unless File.basename(words.first.to_s) == 'find'

        start = words.index { |word| FIND_EXEC.include?(word) }
        return nil unless start

        command = words[(start + 1)..].take_while { |word| !FIND_END.include?(word) }
                                      .reject { |word| word == '{}' }
        command.empty? ? nil : command
      end
    end
  end
end
