# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Creates a throwaway git repository and runs the example inside it.
# Tag an example group with `:git_repo` to use it.
module GitRepoHelper
  def git(*args)
    stdout, stderr, status = Open3.capture3('git', *args)
    raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

    stdout
  end

  def commit_file(name, content = name, message: "Add #{name}")
    File.write(name, content)
    git('add', name)
    git('commit', '-q', '-m', message)
  end

  # A branch with a commit of its own that main then took in (fast-forward), so it is merged
  # and used. A branch only cut from main has never been used, and clean keeps it.
  def merged_branch(name)
    base = git('branch', '--show-current').strip
    git('switch', '-q', '-c', name)
    commit_file("#{name.tr('/', '_')}.txt")
    git('switch', '-q', base)
    git('merge', '-q', '--ff-only', name)
  end

  def head_sha
    git('rev-parse', 'HEAD').strip
  end

  def branch_names
    git('for-each-ref', '--format=%(refname:short)', 'refs/heads/').split("\n")
  end
end

RSpec.configure do |config|
  config.include GitRepoHelper, :git_repo

  config.around(:each, :git_repo) do |example|
    Dir.mktmpdir('gitflash-spec') do |dir|
      Dir.chdir(dir) do
        git('init', '-q', '-b', 'main')
        git('config', 'user.name', 'Spec')
        git('config', 'user.email', 'spec@example.com')
        git('config', 'commit.gpgsign', 'false')
        example.run
      end
    end
  end
end
