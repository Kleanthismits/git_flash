# frozen_string_literal: true

module Gitflash
  module Hook
    # Reads a shell command line as text, without running it: where commands end, and which
    # commands run inside `$(...)`, `<(...)` and backticks. Quotes are followed as the shell
    # does: nothing runs inside single quotes, `$(...)` and backticks run inside double quotes,
    # and a backslash keeps the next character (outside single quotes).
    module ShellText
      SEPARATORS = ";&|\n"

      module_function

      # The command line split on ; & | and newlines outside quotes and substitutions
      def segments(line)
        scan(line).first
      end

      # The scripts the shell runs to build the line: the text inside `$(...)`, `<(...)`,
      # `>(...)` and backticks. Nested ones are found when the caller reads each script in turn.
      def substitutions(line)
        scan(line).last
      end

      # [segments, scripts] in one pass over the line
      def scan(line)
        parts = [+'']
        scripts = []
        index = 0
        quote = nil
        index, quote = step(line, index, quote, parts, scripts) while index < line.length
        [parts.reject { |part| part.strip.empty? }, scripts]
      end

      # Reads what starts at index and returns where to go on, with the quote then open
      def step(line, index, quote, parts, scripts)
        char = line[index]
        return [index + 1, close_single(char, parts)] if quote == "'"
        return take(line, index, index + 2, parts) + [quote] if char == '\\'

        script = substitution(line, index, quote)
        if script
          scripts << line[script.first...script.last]
          return take(line, index, script.last + 1, parts) + [quote]
        end
        plain(char, index, quote, parts)
      end

      def close_single(char, parts)
        parts.last << char
        char == "'" ? nil : "'"
      end

      def plain(char, index, quote, parts)
        if !quote && SEPARATORS.include?(char)
          parts << +''
          return [index + 1, nil]
        end
        parts.last << char
        [index + 1, next_quote(char, quote)]
      end

      def next_quote(char, quote)
        return (char == '"' ? nil : quote) if quote
        return char if ["'", '"'].include?(char)

        nil
      end

      def take(line, from, to, parts)
        parts.last << line[from...to].to_s
        [to]
      end

      # [script start, closing index] of a substitution opening at index, or nil. `<(...)` and
      # `>(...)` only open outside quotes; `$(...)` and backticks also inside double quotes.
      def substitution(line, index, quote)
        if line[index] == '`'
          [index + 1, closing_backtick(line, index + 1)]
        elsif line[index, 2] == '$(' || (quote.nil? && line[index, 2].match?(/\A[<>]\(/))
          [index + 2, closing_paren(line, index + 2)]
        end
      end

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
