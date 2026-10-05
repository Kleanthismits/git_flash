# frozen_string_literal: true

module Gitflash
  module Commands
    # Cherry-picks commits from another branch. `--list` shows the commits of SOURCE whose change
    # is not on the current branch yet (commits with an equivalent patch already here are marked
    # `applied` and never picked). With SHAs, or chosen from a menu in a terminal, it applies them
    # oldest first with `git cherry-pick -x` after saving a snapshot; `gitflash undo` returns to
    # the starting point. On a conflict it stops and lists the files: see PickControl.
    class Pick < Base
      include PickOutcome

      NOTHING = 'Nothing to pick: the changes are already on the current branch'

      # --continue, --skip and --abort are handled by PickControl, everything else by Pick
      def self.command_for(options)
        PickControl::ACTIONS.any? { |action| options[action.to_sym] } ? PickControl : self
      end

      def call(source = nil, *shas)
        usage_error!('input_required', 'Pass the source branch: gitflash pick SOURCE') unless source
        check_idle!
        candidates = cherry_pick.candidates(source_ref(source))
        return list(source, candidates) if options[:list]

        wanted = shas.empty? ? pick_from_menu(candidates) : shas
        return 0 if wanted.nil?

        pick(source, select_candidates(source, candidates, wanted))
      end

      private

      def check_idle!
        return unless cherry_pick.in_progress?

        usage_error!('invalid_usage', 'A cherry-pick is already in progress: use gitflash pick ' \
                                      '--continue, --skip or --abort')
      end

      def source_ref(source)
        ref = cherry_pick.source_ref(source)
        ref || usage_error!('unknown_branch', "Unknown branch '#{source}'")
      end

      def list(source, candidates)
        ui.report(status: 'done', result: { source: source, commits: candidates.map(&:to_h) },
                  text: table(candidates))
      end

      def table(candidates)
        return 'No commits to pick.' if candidates.empty?

        candidates.map { |candidate| row(candidate) }.join("\n")
      end

      def row(candidate)
        stat = "+#{candidate.insertions} -#{candidate.deletions}"
        "#{candidate.applied ? '=' : ' '} #{candidate.short_sha}  " \
          "#{TerminalText.safe(candidate.subject)}  (#{candidate.author}, " \
          "#{candidate.date[0, 10]}, #{candidate.files} files #{stat})"
      end

      # SHAs picked from a menu, nil after telling the user there is nothing to pick
      def pick_from_menu(candidates)
        require_interactive!('Pass the commits to pick: gitflash pick SOURCE SHA...')
        fresh = candidates.reject(&:applied)
        return nothing_chosen('No commits to pick') if fresh.empty?

        chosen = ui.multi_select('Select commits to pick (oldest first)',
                                 fresh.to_h { |candidate| [row(candidate), candidate.sha] })
        chosen.empty? ? nothing_chosen('No commits selected') : chosen
      end

      def nothing_chosen(text)
        report_nothing(text)
        nil
      end

      # The asked-for commits in source order (oldest first), whatever order they were given in
      def select_candidates(source, candidates, wanted)
        found = wanted.map { |arg| find(arg, candidates, source) }
        candidates.select { |candidate| found.include?(candidate) }
      end

      def find(arg, candidates, source)
        matches = candidates.select { |candidate| candidate.sha.start_with?(arg.to_s) }
        return matches.first if arg.to_s.length >= 4 && matches.size == 1

        usage_error!('unknown_commit', "'#{arg}' is not a commit of #{source} that is missing " \
                                       'from the current branch (or it is ambiguous)')
      end

      def pick(source, chosen)
        fresh, applied = chosen.partition { |candidate| !candidate.applied }
        return report_nothing(NOTHING) if fresh.empty?

        plan = build_plan(source, fresh, applied)
        return planned(plan, "Would pick:\n#{bullets(plan)}") if ui.dry_run?
        return cancelled(plan) unless confirm?(plan)

        run(plan)
      end

      def build_plan(source, fresh, applied)
        skipped = applied.map { |c| { sha: c.sha, reason: 'already on the current branch' } }
        { source: source, commits: fresh.map(&:sha), skipped: skipped,
          commit: options[:commit] != false }
      end

      def confirm?(plan)
        ui.confirm?("You are about to pick:\n\n#{bullets(plan)}", plan: plan)
      end

      def run(plan)
        snapshot = take_snapshot("gitflash pick #{plan[:source]}",
                                 scope: %w[branches head worktree], branches: current_branch_names)
        result = cherry_pick.apply(plan[:commits], commit: plan[:commit])
        outcome(plan, result, plan[:commits], snapshot)
      end

      def bullets(plan)
        plan[:commits].map { |sha| "* #{sha[0, 7]}" }.join("\n")
      end

      def report_nothing(text)
        ui.report(status: 'noop', result: { applied: [] }, text: text)
      end
    end
  end
end
