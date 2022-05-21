# frozen_string_literal: true

require File.expand_path('lib/gitflash/version', __dir__)

Gem::Specification.new do |spec|
  spec.name                  = 'gitflash'
  spec.version               = GitFlash::VERSION
  spec.authors               = ['Kleanthis Mitsioulis']
  spec.email                 = ['kleanthismits@hotmail.gr']
  spec.summary               = 'Simplified usage of some git cli commands'
  spec.description           = 'This gem allows you to perform a number of git commands using interactive cli prompts'
  spec.homepage              = 'https://github.com/Kleanthismits/gitflash.git'
  spec.license               = 'MIT'
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.5.0'

  spec.files = Dir['README.md', 'LICENSE',
                   'CHANGELOG.md', 'lib/**/*.rb',
                   'lib/**/*.rake',
                   'gitflash.gemspec', '.github/*.md',
                   'Gemfile', 'Rakefile']

  spec.extra_rdoc_files = ['README.md']

  spec.add_dependency 'thor', '~> 1.2.1'
  spec.add_dependency 'tty-prompt', '~> 0.23.1'

  if ENV['TEST_RAILS_VERSION'].nil?
    spec.add_development_dependency 'rails', '~> 6.0.3'
  else
    spec.add_development_dependency 'rails', ENV['TEST_RAILS_VERSION'].to_s
  end
  spec.add_development_dependency 'codecov', '~> 0.6'
  spec.add_development_dependency 'rake', '~> 13.0.6'
  spec.add_development_dependency 'rspec', '~> 3.11.0'
  spec.add_development_dependency 'rspec-rails', '~> 5.1.2'
  spec.add_development_dependency 'pry', '~> 0.14.1'
  spec.add_development_dependency 'rubocop', '~> 1.28.2'
  spec.add_development_dependency 'rubocop-performance', '~> 1.13.3'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.10.0'
end
