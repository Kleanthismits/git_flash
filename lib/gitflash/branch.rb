# frozen_string_literal: true

require 'time'

module Gitflash
  # A local branch as reported by `git for-each-ref`
  Branch = Data.define(
    :name, :sha, :current, :default, :upstream, :upstream_gone, :ahead, :behind,
    :merged, :last_commit_at, :last_commit_author, :last_commit_subject, :owner
  ) do
    # Records are built without an owner; Ownership#annotate adds it
    def initialize(owner: nil, **fields)
      super
    end

    # Parses one line produced with Repo::BRANCH_FORMAT.
    # `merged_names` is nil when merge status is unknown. `owner` is set by the caller.
    def self.parse(line, default_branch: nil, merged_names: nil)
      name, sha, head, upstream, track, date, author, subject = fields(line)

      new(
        name: name,
        sha: sha,
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

    # { branch name => sha } from `git for-each-ref --format=TIPS_FORMAT refs/heads/`
    def self.parse_tips(output)
      output.to_s.each_line(chomp: true).to_h { |line| line.split(' ', 2) }
            .transform_keys { |ref| ref.delete_prefix(Repo::HEADS) }
    end

    # The record's fields; the full ref name is shortened by removing refs/heads/ only, because
    # `refname:short` gives another name when a tag has the same name.
    def self.fields(line)
      fields = line.split(Repo::SEPARATOR, 8)
      fields[0] = fields[0].delete_prefix(Repo::HEADS)
      fields
    end
    private_class_method :fields

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
  Branch::TIPS_FORMAT = '%(refname) %(objectname)'
end
