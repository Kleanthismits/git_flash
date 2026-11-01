# frozen_string_literal: true

module Gitflash
  # What the reflog of a branch says about its use: when it last moved, and whether it never
  # moved after it was created (`unused`: nobody committed, reset or merged anything on it, so
  # its tip is still the commit it was cut from). A commit date cannot tell this: a branch cut
  # today from an old commit has an old commit date and is reachable from where it was cut.
  BranchActivity = Data.define(:unused, :last_activity_at) do
    # The branches with `unused` and `last_activity_at` set from their reflogs, read in one git
    # call. Without a reflog, or when git fails, a branch is returned as it is.
    def self.annotate(branches, bash: Git::BashCommand)
      return branches if branches.empty?

      refs = branches.map { |branch| "#{Repo::HEADS}#{branch.name}" }
      format = "--format=#{BranchActivity::FORMAT}"
      found = parse(bash.exec('git', 'log', '-g', '--date=unix', format, *refs, '--'))
      branches.map do |branch|
        activity = found[branch.name]
        activity ? branch.with(**activity.to_h) : branch
      end
    rescue Git::CommandError
      branches
    end

    # { branch name => BranchActivity } from `git log -g --date=unix --format=FORMAT REFS...`,
    # which lists the entries of each ref newest first. A branch without a reflog (reflogs off,
    # or its entries expired) has no entry, so nothing is known about it.
    def self.parse(output)
      entries = output.to_s.each_line(chomp: true).filter_map { |line| entry(line) }
      entries.group_by(&:first).transform_values do |rows|
        new(unused: rows.size == 1 && rows.first[2].start_with?(BranchActivity::CREATED),
            last_activity_at: Time.at(rows.first[1]))
      end
    end

    # [branch name, unix time, subject]. A ref name cannot contain `@{`, so the selector is the
    # last one.
    def self.entry(line)
      selector, subject = line.split(Repo::SEPARATOR, 2)
      ref, time = selector.to_s.match(/\A(.+)@\{(\d+)\}\z/)&.captures
      ref && [ref.delete_prefix(Repo::HEADS), time.to_i, subject.to_s]
    end
    private_class_method :entry
  end
  BranchActivity::CREATED = 'branch: Created from'
  BranchActivity::FORMAT = '%gD%x1f%gs'
end
