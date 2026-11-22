# frozen_string_literal: true

require File.expand_path('lib/gitflash/version', __dir__)
Gem::Specification.new do |spec|
  spec.name                  = 'gitflash'
  spec.version               = Gitflash::VERSION
  spec.authors               = ['Kleanthis Mitsioulis']
  spec.email                 = ['kleanthismits@hotmail.gr']
  spec.summary               = 'Safety net and cleanup for git repos that AI coding agents work in'
  spec.description           = 'Snapshots and undo for plain git, cleanup of agent branches ' \
                               'and worktrees, one JSON contract for CLI, MCP, skill and hook'
  spec.homepage              = 'https://github.com/Kleanthismits/git_flash'
  spec.license               = 'MIT'
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = Gem::Requirement.new('>= 3.3')

  # Runtime dependencies
  spec.add_dependency 'mcp', '~> 1.8'
  spec.add_dependency 'thor', '>= 1.4', '< 2'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  spec.executables = ['gitflash']

  # prevents Gem::InvalidSpecificationException
  spec.files = Dir.glob('lib/**/*') + %w[
    bin/gitflash CHANGELOG.md LICENSE README.md command_descriptions.yml schema/v1.json
    skills/gitflash/SKILL.md
  ]

  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/Kleanthismits/git_flash/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/Kleanthismits/git_flash#readme'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/Kleanthismits/git_flash/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.extra_rdoc_files = ['README.md']
end
