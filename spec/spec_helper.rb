require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start do
  skip 'lib/gitflash/version.rb'
end

require 'gitflash'

# On macOS /usr/bin/git is a shim that looks up the real git on every call (about 40 ms each).
# The specs make thousands of git calls, so put the real binary first on the PATH.
if RUBY_PLATFORM.include?('darwin')
  real_git = `xcrun --find git 2>/dev/null`.strip
  ENV['PATH'] = "#{File.dirname(real_git)}:#{ENV.fetch('PATH')}" unless real_git.empty?
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
