require 'simplecov'
require 'simplecov-lcov'
require 'gitflash'

# frozen_string_literal: true

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start do
  add_filter 'lib/gitflash/version.rb'
end
#  'rails' do
#   add_filter 'spec/'
#   add_filter '.github/'
#   add_filter 'lib/generators/templates/'
#   add_filter 'lib/lokalise_rails/version'
# end

# if ENV['CI'] == 'true'
#   require 'codecov'
#   SimpleCov.formatter = SimpleCov::Formatter::Codecov
# end

# ENV['RAILS_ENV'] = 'test'

# require_relative '../spec/dummy/config/environment'
# ENV['RAILS_ROOT'] ||= "#{File.dirname(__FILE__)}../../../spec/dummy"
