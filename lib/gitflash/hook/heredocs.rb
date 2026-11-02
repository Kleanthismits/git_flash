# frozen_string_literal: true

module Gitflash
  module Hook
    # Here-documents in a shell command line (see ShellText). `cat <<'EOF'` takes the lines after
    # the command, up to a line that is only `EOF`, as its input. Those lines are text, not
    # commands: read as commands, an apostrophe in them would open a quote that hides the real
    # commands after `EOF`, and a git command quoted in them would count as one that runs.
    module Heredocs
      # body: the lines up to the delimiter. quoted: the delimiter was quoted (`<<'EOF'`,
      # `<<"EOF"`, `<<\EOF`), so nothing in the body runs; unquoted, `$(...)` and backticks in it
      # run as they do inside double quotes.
      Heredoc = Data.define(:body, :quoted)
      # A heredoc whose body starts after the current line; part is the segment it belongs to
      Pending = Data.define(:delimiter, :quoted, :strip_tabs, :part)
      WORD_END = /[\s;&|<>()]/
      BLANKS = [' ', "\t"].freeze

      module_function

      # [Pending, index after the delimiter] for a `<<` at index, or nil. `<<<` is a here-string,
      # whose word is on the same line.
      def open(line, index, part)
        return nil unless line[index, 2] == '<<' && line[index + 2] != '<'

        from = index + 2
        strip_tabs = line[from] == '-'
        from += 1 if strip_tabs
        from += 1 while BLANKS.include?(line[from])
        delimiter, quoted, to = word(line, from)
        return nil if delimiter.empty?

        [Pending.new(delimiter: delimiter, quoted: quoted, strip_tabs: strip_tabs, part: part), to]
      end

      # [the word at index without its quotes, whether it had quotes or backslashes, index after]
      def word(line, index)
        text = +''
        quoted = false
        until index >= line.length || line[index].match?(WORD_END)
          piece, index, marked = word_piece(line, index)
          text << piece
          quoted ||= marked
        end
        [text, quoted, index]
      end

      # [text, index after it, whether it was quoted] for one quoted string, escape or character
      def word_piece(line, index)
        char = line[index]
        return [line[index + 1].to_s, index + 2, true] if char == '\\'
        return [char, index + 1, false] unless ["'", '"'].include?(char)

        close = line.index(char, index + 1) || line.length
        [line[(index + 1)...close].to_s, close + 1, true]
      end

      # The bodies of the pending heredocs, in order, read from index (the start of the next line).
      # Returns [[part, Heredoc]...] and the index after the last body.
      def bodies(line, index, pending)
        found = pending.map do |doc|
          body, index = body(line, index, doc)
          [doc.part, Heredoc.new(body: body, quoted: doc.quoted)]
        end
        [found, index]
      end

      # Lines up to one that is only the delimiter (`<<-` strips leading tabs first), or to the end
      # of the text when none is
      def body(line, index, doc)
        body = +''
        while index < line.length
          stop = line.index("\n", index) || line.length
          text = line[index...stop]
          index = stop + 1
          return [body, index] if (doc.strip_tabs ? text.sub(/\A\t+/, '') : text) == doc.delimiter

          body << text << "\n"
        end
        [body, index]
      end

      # The scripts an unquoted body runs: `$(...)` and backticks, read as inside double quotes,
      # where a quote is a plain character
      def substitutions(body)
        scripts = []
        index = 0
        while index < body.length
          script = ShellText.substitution(body, index, '"')
          scripts << body[script.first...script.last] if script
          index = script ? script.last + 1 : after(body, index)
        end
        scripts
      end

      def after(body, index)
        body[index] == '\\' ? index + 2 : index + 1
      end

      # The scripts the heredocs of a command run, given the command's words: the whole body when
      # a shell without `-c` reads it as its script (`bash <<'EOF'`, `sh -s`), else the
      # substitutions of an unquoted body. A shell that runs a script file reads the heredoc as
      # data instead; reading it as a script then costs at most an extra snapshot.
      def scripts(heredocs, words)
        reads_script = stdin_script?(words)
        heredocs.flat_map do |heredoc|
          next [heredoc.body] if reads_script
          next [] if heredoc.quoted

          substitutions(heredoc.body)
        end
      end

      def stdin_script?(words)
        CommandParser::SHELLS.include?(File.basename(words.first.to_s)) &&
          words.none? { |word| word.match?(CommandParser::SCRIPT_FLAG) }
      end
    end
  end
end
