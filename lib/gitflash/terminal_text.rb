# frozen_string_literal: true

module Gitflash
  # Makes text from the repository safe to print in a terminal. Commit subjects, author names
  # and git messages are written by other people; control characters in them could move the
  # cursor, rewrite earlier output or set the clipboard (OSC 52). They are shown as escapes.
  # Newlines and tabs stay.
  module TerminalText
    UNSAFE = /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]/

    module_function

    def safe(text)
      text.to_s.scrub.gsub(UNSAFE) do |char|
        format(char.ord > 0xFF ? '\\u%04X' : '\\x%02X', char.ord)
      end
    end

    # Text that must stay on one line, such as a path inside a bullet list: as `safe`, and a
    # newline or tab in it is shown as an escape too, so it cannot start a fake row. A literal
    # backslash is doubled first, so two different texts never look the same (a real newline
    # shows as `\n`, the two characters backslash and n as `\\n`); that keeps menu labels unique.
    def line(text)
      doubled = text.to_s.scrub.gsub('\\') { '\\\\' }
      safe(doubled).gsub("\n") { '\\n' }.gsub("\t") { '\\t' }
    end
  end
end
