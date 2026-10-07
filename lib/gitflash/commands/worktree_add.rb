# frozen_string_literal: true

module Gitflash
  module Commands
    # Adds a worktree for an existing, remote or new branch. Additive, so it needs no
    # confirmation and no snapshot. A branch created here is marked as agent work.
    class WorktreeAdd < Base
      def call(branch = nil)
        validate_name!(branch)
        worktrees = Worktrees.new(repo: repo)
        source = worktrees.source_for(branch)
        check_options!(source)
        check_free!(worktrees, branch, source)

        plan = build_plan(branch, source)
        if ui.dry_run?
          return planned(plan,
                         "Would add worktree #{plan[:path]} on #{branch} (#{source})")
        end

        add(worktrees, plan)
      end

      private

      def validate_name!(branch)
        usage_error!('invalid_usage', 'Pass the branch: gitflash wt add BRANCH') if branch.nil?
        valid = !branch.start_with?('-') && ref_format_ok?(branch)
        usage_error!('invalid_usage', "Invalid branch name '#{branch}'") unless valid
      end

      def ref_format_ok?(branch)
        _stdout, _stderr, success = Git::BashCommand.capture('git', 'check-ref-format', '--branch',
                                                             branch)
        success
      end

      def check_options!(source)
        return unless options[:from] && source != :new

        usage_error!('invalid_options', '--from only applies to a new branch, but the branch ' \
                                        "already exists (#{source})")
      end

      def check_free!(worktrees, branch, source)
        return unless source == :existing

        holder = worktrees.list.find { |worktree| worktree.branch == branch }
        return unless holder

        usage_error!('invalid_usage', "Branch #{branch} is already checked out at #{holder.path}")
      end

      def build_plan(branch, source)
        path = target_path(branch)
        if File.exist?(path) && !(File.directory?(path) && Dir.empty?(path))
          usage_error!('invalid_usage', "#{path} already exists and is not an empty directory")
        end

        { branch: branch, path: path, source: source.to_s, from: options[:from],
          owner: source == :existing ? nil : owner }
      end

      def target_path(branch)
        return File.expand_path(options[:path]) if options[:path]

        config.worktree_path(root: repo.main_root, branch: branch)
      end

      def owner
        value = options[:owner] || 'agent'
        return value if Ownership::OWNERS.include?(value)

        usage_error!('invalid_options', "Unknown owner '#{value}' (use agent or human)")
      end

      def add(worktrees, plan)
        source = plan[:source].to_sym
        result = worktrees.add(plan[:path], branch: plan[:branch], source: source,
                                            start: plan[:from])
        git_error!('worktree add', result) unless result.success?

        Ownership.new.mark(plan[:branch], plan[:owner]) if plan[:owner]
        report(plan)
      end

      def report(plan)
        ui.report(status: 'done', plan: plan, result: outcome(plan),
                  text: "Added worktree #{plan[:path]} on #{plan[:branch]}")
      end

      def outcome(plan)
        head = Git::BashCommand.exec('git', '-C', plan[:path], 'rev-parse', 'HEAD').strip
        plan.slice(:branch, :path, :source, :owner).merge(head: head)
      end
    end
  end
end
