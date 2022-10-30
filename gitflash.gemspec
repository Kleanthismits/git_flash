# frozen_string_literal: true

require File.expand_path('lib/gitflash/version', __dir__)
Gem::Specification.new do |spec|
  spec.name                  = 'gitflash'
  spec.version               = Gitflash::VERSION
  spec.authors               = ['Kleanthis Mitsioulis']
  spec.email                 = ['kleanthismits@hotmail.gr']
  spec.summary               = 'Simplified usage of some git cli commands'
  spec.description           = 'This gem allows you to perform a number of git commands using interactive cli prompts'
  spec.homepage              = 'https://github.com/Kleanthismits/gitflash.git'
  spec.license               = 'MIT'
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.executables = ['gitflash']

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/Kleanthismits/git_flash/blob/main/CHANGELOG.md'
  spec.extra_rdoc_files = ['README.md']

  spec.require_paths = ['lib']

  if ENV['TEST_RAILS_VERSION'].nil?
    spec.add_development_dependency 'rails', '~> 6.0.4.8'
  else
    spec.add_development_dependency 'rails', ENV['TEST_RAILS_VERSION'].to_s
  end
end
