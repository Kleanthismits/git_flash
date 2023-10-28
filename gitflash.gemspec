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
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.executables = ['gitflash']

  # prevents Gem::InvalidSpecificationException
  spec.files = Dir.glob('{bin,lib,template}/**/*') + %w[LICENSE README.md]

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/Kleanthismits/git_flash/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.extra_rdoc_files = ['README.md']
end
