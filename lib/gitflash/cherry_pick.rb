# frozen_string_literal: true

module Gitflash
  # Cherry-picking between branches: finds the commits of a source branch whose change is not on
  # the current branch yet, applies them oldest first, and wraps git's own sequence controls.
  # All git access for `gitflash pick` is here; it never prompts or prints.
  class CherryPick
    # `applied` is true when an equivalent change is already on the current branch
    Candidate = Data.define(:sha, :subject, :author, :date, :applied, :files, :insertions,
                            :deletions) do
      def short_sha = sha[0, 7]

      def to_h
        super.merge(short_sha: short_sha, status: applied ? 'applied' : 'new')
             .except(:applied)
      end
    end

    # The state of an unfinished pick: files with conflicts and the commits still to apply
    Progress = Data.define(:conflicted, :remaining, :current)

    ENV_NO_EDITOR = { 'GIT_EDITOR' => 'true', 'GIT_SEQUENCE_EDITOR' => 'true' }.freeze

    def initialize(bash: Git::BashCommand)
      @bash = bash
    end

    # The full ref of a local (or remote-tracking) branch, nil when there is none
    def source_ref(name)
      return nil if name.to_s.empty? || name.start_with?('-')

      ["#{Repo::HEADS}#{name}", "refs/remotes/#{name}"].find { |ref| ref?(ref) }
    end

    # Commits of `source_ref` that are not merges, oldest first, each marked as applied when an
    # equivalent change (same patch) is already on HEAD
    def candidates(source_ref)
      output = @bash.exec('git', 'log', '-z', '--left-right', '--cherry-mark', '--right-only',
                          '--no-merges', '--reverse', '--shortstat', "--format=#{LogParser::FORMAT}",
                          "HEAD...#{source_ref}", '--')
      eligible = eligible_shas(source_ref)
      LogParser.parse(output).select { |candidate| eligible.include?(candidate.sha) }.uniq(&:sha)
    end

    # Applies the commits (full shas, in the given order) with `git cherry-pick`.
    # `record_origin` adds "(cherry picked from ...)" to each message; `commit: false` only stages.
    def apply(shas, record_origin: true, commit: true)
      args = ['cherry-pick']
      args << '-x' if record_origin
      args << '--no-commit' unless commit
      run(*args, *shas)
    end

    def continue = run('cherry-pick', '--continue')

    def abort = run('cherry-pick', '--abort')

    def skip = run('cherry-pick', '--skip')

    # True while a cherry-pick waits for the user (conflicts or a stopped sequence)
    def in_progress?
      ref?('CHERRY_PICK_HEAD') || File.exist?(todo_path)
    end

    def progress
      Progress.new(conflicted: conflicted_files, remaining: remaining, current: current)
    end

    private

    # The commits of the source that are not merges and not on HEAD, listed by git without any
    # text a commit author controls. A commit message holding the separators of the log format
    # could forge extra records; only SHAs found here become candidates.
    def eligible_shas(source_ref)
      @bash.exec('git', 'rev-list', '--right-only', '--no-merges', "HEAD...#{source_ref}", '--')
           .lines(chomp: true).to_set
    end

    def conflicted_files
      stdout, _stderr, success = @bash.capture('git', 'diff', '--name-only', '--diff-filter=U',
                                               '-z')
      success ? stdout.split("\0") : []
    end

    # Commits still to apply after the one that stopped, as full shas
    def remaining
      return [] unless File.exist?(todo_path)

      shas = File.readlines(todo_path, chomp: true).filter_map { |line| line[/\Apick (\h+)/, 1] }
      shas.filter_map { |sha| full_sha(sha) }.reject { |sha| sha == current }
    end

    def current
      full_sha('CHERRY_PICK_HEAD')
    end

    def full_sha(ref)
      stdout, _stderr, success = @bash.capture('git', 'rev-parse', '--verify', '--quiet',
                                               "#{ref}^{commit}")
      success ? stdout.strip : nil
    end

    def ref?(ref)
      _stdout, _stderr, success = @bash.capture('git', 'rev-parse', '--verify', '--quiet', ref)
      success
    end

    def todo_path
      stdout, _stderr, success = @bash.capture('git', 'rev-parse', '--path-format=absolute',
                                               '--git-path', 'sequencer/todo')
      success ? stdout.strip : ''
    end

    def run(*)
      stdout, stderr, success = @bash.capture('git', *, env: ENV_NO_EDITOR)
      Result.new(success: success,
                 output: [stdout, stderr].map(&:strip).reject(&:empty?).join("\n"))
    end
  end
end
