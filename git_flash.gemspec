# frozen_string_literal: true

require File.expand_path('lib/git_flash/version', __dir__)

Gem::Specification.new do |spec|
  spec.name                  = 'git_flash'
  spec.version               = GitFlash::VERSION
  spec.authors               = ['Kleanthis Mitsioulis']
  spec.email                 = ['kleanthismits@hotmail.gr']
  spec.summary               = 'Simplified usage of some git cli commands'
  spec.description           = 'This gem allows you to perform a number of git commands using interactive cli prompts'
  spec.homepage              = 'https://github.com/Kleanthismits/git_flash.git'
  spec.license               = 'MIT'
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.5.0'

  spec.files = Dir['README.md', 'LICENSE',
                   'CHANGELOG.md', 'lib/**/*.rb',
                   'lib/**/*.rake',
                   'git_flash.gemspec', '.github/*.md',
                   'Gemfile', 'Rakefile']

  spec.extra_rdoc_files = ['README.md']

  spec.add_dependency 'tty-prompt', '~> 0.23.1'
  spec.add_development_dependency 'rubocop', '~> 1.28.2'
  spec.add_development_dependency 'rubocop-performance', '~> 1.13.3'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.10.0'
end
