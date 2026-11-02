# frozen_string_literal: true

module Gitflash
  module Hook
    # Reads a shell command line as text, without running it: where commands end, and which
    # commands run inside `$(...)`, `<(...)` and backticks. Quotes are followed as the shell
    # does: nothing runs inside single quotes, `$(...)` and backticks run inside double quotes,
    # and a backslash keeps the next character (outside single quotes). Heredoc bodies are taken
    # out of the line and handed back with the command that reads them (see Heredocs).
    module ShellText
      SEPARATORS = ";&|\n"

      # What one pass over a line collects. heredocs: { segment index => [Heredoc] }
      Scan = Struct.new(:parts, :scripts, :pending, :heredocs)

      module_function

      # The command line split on ; & | and newlines outside quotes and substitutions, as
      # [segment, heredocs] pairs: the heredocs are the ones that segment reads
      def commands(line)
        scan(line).first
      end

      # The scripts the shell runs to build the line: the text inside `$(...)`, `<(...)`,
      # `>(...)` and backticks. Nested ones are found when the caller reads each script in turn.
      def substitutions(line)
        scan(line).last
      end

      # [commands, scripts] in one pass over the line
      def scan(line)
        state = Scan.new([+''], [], [], {})
        index = 0
        quote = nil
        index, quote = step(line, index, quote, state) while index < line.length
        commands = state.parts.each_with_index.filter_map do |part, at|
          [part, state.heredocs.fetch(at, [])] unless part.strip.empty?
        end
        [commands, state.scripts]
      end

      # Reads what starts at index and returns where to go on, with the quote then open
      def step(line, index, quote, state)
        char = line[index]
        return [index + 1, close_single(char, state.parts)] if quote == "'"
        return take(line, index, index + 2, state.parts) + [quote] if char == '\\'
        return [comment_end(line, index), nil] if quote.nil? && comment?(line, index)

        opened(line, index, quote, state) || plain(line, index, quote, state)
      end

      # Takes a heredoc or a substitution that opens at index, or returns nil
      def opened(line, index, quote, state)
        (quote.nil? && heredoc(line, index, state)) || substituted(line, index, quote, state)
      end

      # Takes a substitution that opens at index, or returns nil
      def substituted(line, index, quote, state)
        script = substitution(line, index, quote)
        return nil unless script

        state.scripts << line[script.first...script.last]
        take(line, index, script.last + 1, state.parts) + [quote]
      end

      # Takes `<<WORD` at index, whose body is read after the end of this line, or returns nil
      def heredoc(line, index, state)
        pending, to = Heredocs.open(line, index, state.parts.length - 1)
        return nil unless pending

        state.pending << pending
        take(line, index, to, state.parts) + [nil]
      end

      # A `#` that starts a word outside quotes starts a comment, which runs to the end of the
      # line; an apostrophe in it (`# don't`) must not open a quote
      def comment?(line, index)
        line[index] == '#' && (index.zero? || line[index - 1].match?(/[\s;&|()]/))
      end

      def comment_end(line, index)
        line.index("\n", index) || line.length
      end

      def close_single(char, parts)
        parts.last << char
        char == "'" ? nil : "'"
      end

      def plain(line, index, quote, state)
        char = line[index]
        if !quote && SEPARATORS.include?(char)
          state.parts << +''
          return [index + 1, nil] unless char == "\n" && state.pending.any?

          return [bodies(line, index + 1, state), nil]
        end
        state.parts.last << char
        [index + 1, next_quote(char, quote)]
      end

      # Reads the bodies of the heredocs opened on the line that just ended; returns the index
      # after them
      def bodies(line, index, state)
        found, index = Heredocs.bodies(line, index, state.pending)
        found.each { |part, heredoc| (state.heredocs[part] ||= []) << heredoc }
        state.pending.clear
        index
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
          [index + 1, ShellQuotes.closing_backtick(line, index + 1)]
        elsif line[index, 2] == '$(' || (quote.nil? && line[index, 2].match?(/\A[<>]\(/))
          [index + 2, ShellQuotes.closing_paren(line, index + 2)]
        end
      end
    end
  end
end
