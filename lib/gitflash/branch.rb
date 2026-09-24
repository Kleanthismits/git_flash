# frozen_string_literal: true

require 'time'

module Gitflash
  # A local branch as reported by `git for-each-ref`
  Branch = Data.define(
    :name, :current, :default, :upstream, :upstream_gone, :ahead, :behind,
    :merged, :last_commit_at, :last_commit_author, :last_commit_subject
  ) do
    # Parses one line produced with Repo::BRANCH_FORMAT.
    # `merged_names` is nil when merge status is unknown.
    def self.parse(line, default_branch: nil, merged_names: nil)
      name, head, upstream, track, date, author, subject = line.split(Repo::SEPARATOR, 7)

      new(
        name: name,
        current: head == '*',
        default: name == default_branch,
        upstream: upstream.to_s.empty? ? nil : upstream,
        upstream_gone: track == 'gone',
        ahead: track.to_s[/ahead (\d+)/, 1].to_i,
        behind: track.to_s[/behind (\d+)/, 1].to_i,
        merged: merged_names&.include?(name),
        last_commit_at: Time.iso8601(date),
        last_commit_author: author,
        last_commit_subject: subject.to_s
      )
    end

    alias_method :current?, :current
    alias_method :default?, :default
    alias_method :upstream_gone?, :upstream_gone

    def stale?(days, now: Time.now)
      last_commit_at < now - (days * 86_400)
    end

    def to_h
      super.merge(last_commit_at: last_commit_at.iso8601)
    end
  end
end
