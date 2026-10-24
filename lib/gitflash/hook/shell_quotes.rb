# frozen_string_literal: true

module Gitflash
  module Hook
    # Where quoted text and substitutions end in a shell command line (see ShellText)
    module ShellQuotes
      module_function

      # The first backtick at or after index that no backslash escapes, or the end of the line
      def closing_backtick(line, index)
        while index < line.length
          return index if line[index] == '`'

          index += line[index] == '\\' ? 2 : 1
        end
        line.length
      end

      # The `)` that closes a parenthesis opened before index, skipping quoted text and nested
      # substitutions and subshells, or the end of the line
      def closing_paren(line, index)
        while index < line.length
          return index if line[index] == ')'

          index = after_in_parens(line, index)
        end
        line.length
      end

      def after_in_parens(line, index)
        case line[index]
        when '\\' then index + 2
        when "'" then closing_single(line, index + 1) + 1
        when '"' then closing_double(line, index + 1) + 1
        when '`' then closing_backtick(line, index + 1) + 1
        when '(' then closing_paren(line, index + 1) + 1
        else index + 1
        end
      end

      def closing_single(line, index)
        line.index("'", index) || line.length
      end

      # The `"` that closes a double-quoted string opened before index
      def closing_double(line, index)
        while index < line.length
          return index if line[index] == '"'

          index = after_in_double(line, index)
        end
        line.length
      end

      def after_in_double(line, index)
        return index + 2 if line[index] == '\\'
        return closing_backtick(line, index + 1) + 1 if line[index] == '`'
        return closing_paren(line, index + 2) + 1 if line[index, 2] == '$('

        index + 1
      end
    end
  end
end
