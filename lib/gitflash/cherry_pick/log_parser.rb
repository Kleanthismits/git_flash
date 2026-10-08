# frozen_string_literal: true

module Gitflash
  class CherryPick
    # Reads the output of `git log -z --shortstat --format=FORMAT` into Candidate records.
    #
    # One field per line: a subject or an author name cannot hold a newline, and `-z` ends each
    # commit with a NUL, which text cannot hold either, so the framing is unambiguous whatever a
    # commit message says. Git prints the fields of a commit, a NUL, the stat of that commit and
    # the fields of the next one. So chunk 0 holds the fields of commit 0, chunk i the stat of
    # commit i-1 and the fields of commit i, and the last chunk only a stat.
    module LogParser
      FORMAT = '%m%n%H%n%s%n%an%n%cI'
      FIELDS = 5

      module_function

      def parse(output)
        chunks = output.split("\0", -1)
        stats = stats_of(chunks)
        fields = chunks[0...-1].map { |chunk| chunk.lines(chomp: true).last(FIELDS) }
        fields.each_with_index.filter_map do |row, index|
          candidate(row, stats[index + 1]) if row.size == FIELDS
        end
      end

      def stats_of(chunks)
        last = chunks.size - 1
        chunks.each_with_index.map { |chunk, index| stat_part(chunk, index == last) }
      end

      # The part of a chunk before the fields of the next commit; the last chunk is all stat
      def stat_part(chunk, last)
        last ? chunk : chunk.lines(chomp: true)[0...-FIELDS].to_a.join("\n")
      end

      def candidate(row, stat_text)
        mark, sha, subject, author, date = row
        files, insertions, deletions = stat(stat_text)
        Candidate.new(sha: sha, subject: subject, author: author, date: date,
                      applied: mark == '=', files: files, insertions: insertions,
                      deletions: deletions)
      end

      def stat(text)
        [text[/(\d+) files? changed/, 1], text[/(\d+) insertions?\(\+\)/, 1],
         text[/(\d+) deletions?\(-\)/, 1]].map(&:to_i)
      end
    end
  end
end
