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

      # [files, insertions, deletions] from a line such as
      # " 2 files changed, 3 insertions(+), 1 deletion(-)". Split on commas and spaces, with no
      # regular expression, so a long run of digits in the text costs only its own length.
      def stat(text)
        line = text.to_s.lines.map(&:strip).reject(&:empty?).last.to_s
        counts = { 'file' => 0, 'insertion' => 0, 'deletion' => 0 }
        line.split(',').each { |part| tally(counts, part) }
        counts.values
      end

      def tally(counts, part)
        count, label = part.strip.split(' ', 2)
        number = Integer(count, 10, exception: false)
        kind = counts.keys.find { |name| label.to_s.start_with?(name) }
        counts[kind] = number if number && kind
      end
    end
  end
end
