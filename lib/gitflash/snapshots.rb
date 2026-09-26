# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module Gitflash
  # Creates, lists and deletes snapshots.
  #
  # Each snapshot is one commit under refs/gitflash/snapshots/<id>. Its message is the snapshot
  # metadata as JSON, its tree is empty, and its parents are every commit the snapshot refers
  # to, so git keeps them all as long as the ref exists. Nothing outside git's own object store
  # is written, and linked worktrees share the snapshots.
  class Snapshots
    REF_PREFIX = 'refs/gitflash/snapshots/'
    SCOPES = %w[branches head worktree stashes].freeze

    def initialize(bash: Git::BashCommand, clock: -> { Time.now })
      @bash = bash
      @clock = clock
      @capture = StateCapture.new(bash: bash)
    end

    # Saves the current state. `branches` limits the recorded branches (nil records all).
    # Returns the latest snapshot instead when nothing changed since it was taken.
    def create(reason:, scope: SCOPES, branches: nil)
      state = @capture.call(scope, branches)
      latest = list.first
      return latest if latest&.state == state

      store(Snapshot.new(**identity, reason: reason, **state))
    end

    # Snapshots, newest first
    def list
      git('for-each-ref', '--sort=-refname', '--format=%(contents:subject)', REF_PREFIX)
        .each_line(chomp: true).reject(&:empty?)
        .map { |line| Snapshot.from_h(JSON.parse(line)) }
    end

    def find(id)
      list.find { |snapshot| snapshot.id == id }
    end

    def delete(id)
      git('update-ref', '-d', "#{REF_PREFIX}#{id}")
    end

    private

    def git(*)
      @bash.exec('git', *)
    end

    def identity
      now = @clock.call.utc
      { id: "#{now.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(2)}", created_at: now.iso8601 }
    end

    def store(snapshot)
      meta = @capture.commit_tree(@capture.empty_tree, parents: snapshot.object_ids,
                                                       message: JSON.generate(snapshot.to_h))
      git('update-ref', "#{REF_PREFIX}#{snapshot.id}", meta)
      snapshot
    end
  end
end
