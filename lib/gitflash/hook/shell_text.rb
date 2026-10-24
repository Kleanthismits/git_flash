# frozen_string_literal: true

module Gitflash
  module Hook
    # Reads a shell command line as text, without running it: where commands end, and which
    # commands run inside `$(...)`, `<(...)` and backticks
    module ShellText
      SEPARATORS = ";&|\n"
      PAREN_DEPTH = { '(' => 1, ')' => -1 }.freeze

      module_function

      # The command line split on unquoted ; & | and newlines, never inside `$(...)` or
      # backticks. A backslash keeps the next character (outside single quotes), so `"a\"b"`
      # stays one quoted word.
      def segments(line)
        parts = [+'']
        nesting = Nesting.new
        each_char(line) do |char, quote, escaped|
          split = nesting.separator?(char, parts.last[-1], quote, escaped)
          split ? parts << +'' : parts.last << char
        end
        parts.reject { |part| part.strip.empty? }
      end

      # How deep a line is inside `$(...)`, `<(...)`, `>(...)` and backticks, one character at a
      # time
      class Nesting
        def initialize
          @parens = 0
          @backtick = false
        end

        # Reads the character and says whether it ends a command here
        def separator?(char, previous, quote, escaped)
          return false if escaped || quote == "'"

          read(char, previous)
          !quote && outside? && SEPARATORS.include?(char)
        end

        def read(char, previous)
          if char == '`'
            @backtick = !@backtick
          elsif @parens.positive?
            @parens += PAREN_DEPTH.fetch(char, 0)
          elsif char == '(' && previous && '$<>'.include?(previous)
            @parens = 1
          end
        end

        def outside?
          @parens.zero? && !@backtick
        end
      end

      # The scripts the shell runs to build the line: the text inside `$(...)`, `<(...)`,
      # `>(...)` and backticks, outside single quotes. Nested ones are found when the caller
      # reads each script in turn.
      def substitutions(line)
        scripts = []
        index = 0
        while index < line.length
          index = skip_single_quoted(line, index)
          script, index = substitution_at(line, index)
          scripts << script if script
        end
        scripts
      end

      # Yields each character with the open quote (nil, "'" or '"') and whether a backslash
      # escaped it
      def each_char(line)
        quote = nil
        escaped = false
        line.each_char do |char|
          yield char, quote, escaped
          if escaped then escaped = false
          elsif char == '\\' && quote != "'" then escaped = true
          elsif quote then quote = nil if char == quote
          elsif ["'", '"'].include?(char) then quote = char
          end
        end
      end

      def skip_single_quoted(line, index)
        return index unless line[index] == "'" && !escaped_at?(line, index)

        closing = line.index("'", index + 1)
        closing ? closing + 1 : line.length
      end

      # [script, next index] for a substitution starting at index, or [nil, index + 1]
      def substitution_at(line, index)
        return [nil, index + 1] if escaped_at?(line, index)

        closing = closing_of(line, index)
        return [nil, index + 1] unless closing

        start = line[index] == '`' ? index + 1 : index + 2
        [line[start...closing], closing + 1]
      end

      # Where the substitution that opens at index ends, or nil when none opens there
      def closing_of(line, index)
        return line.index('`', index + 1) || line.length if line[index] == '`'

        matching_paren(line, index + 1) if line[index, 2].match?(/\A[$<>]\(/)
      end

      # Index of the `)` that closes the `(` at index, or the end of the line
      def matching_paren(line, index)
        depth = 0
        (index...line.length).each do |position|
          next if escaped_at?(line, position)

          depth += PAREN_DEPTH.fetch(line[position], 0)
          return position if depth.zero?
        end
        line.length
      end

      def escaped_at?(line, index)
        backslashes = 0
        backslashes += 1 while index - backslashes - 1 >= 0 && line[index - backslashes - 1] == '\\'
        backslashes.odd?
      end
    end
  end
end
