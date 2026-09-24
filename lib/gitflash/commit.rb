# frozen_string_literal: true

require 'time'

module Gitflash
  # A commit as reported by `git log`
  Commit = Data.define(:sha, :subject, :author, :committed_at) do
    # Parses one line produced with Repo::COMMIT_FORMAT
    def self.parse(line)
      sha, subject, author, date = line.split(Repo::SEPARATOR, 4)
      new(sha: sha, subject: subject.to_s, author: author, committed_at: Time.iso8601(date))
    end

    def label
      "#{sha} - #{subject}"
    end

    def to_h
      super.merge(committed_at: committed_at.iso8601)
    end
  end
end
