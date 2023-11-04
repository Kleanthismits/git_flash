# frozen_string_literal: true

# Suppress the zeitwerk warning for overriding :require method temporarily
original_verbose = $VERBOSE
$VERBOSE = nil

require 'zeitwerk'
require 'pry'

loader = Zeitwerk::Loader.for_gem
loader.setup

# Restore the original warning level
$VERBOSE = original_verbose

module Gitflash
end
