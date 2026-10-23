ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Run tests in a single process. Forked parallel workers hang on macOS
  # (Objective-C fork safety), and the suite takes seconds anyway.
  # Opt in with e.g. PARALLEL_WORKERS=4 bin/rails test.
  parallelize(workers: 1)

  # Fixtures are declared per test class — do not load all globally.

  # Add more helper methods to be used by all tests here...
end
