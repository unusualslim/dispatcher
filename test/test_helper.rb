ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Run tests in a single process. Forked parallel workers hang on macOS
  # (Objective-C fork safety), and the suite takes seconds anyway.
  # Opt in with e.g. PARALLEL_WORKERS=4 bin/rails test.
  parallelize(workers: 1)

  # Fixtures are declared per test class — do not load all globally.

  # A staff user holding one role with these area levels (and, unless limited, every feature right and data flag).
  def staff_user(email, levels, features: User::FEATURES.keys, flags: User::DATA_FLAGS.keys, **attrs)
    role = Role.create!(name: "Test role #{SecureRandom.hex(4)}", area_levels: levels, features: features,
                        data_flags: flags)
    User.create!(email: email, password: 'password123', role: 'staff', **attrs).tap { |user| user.roles << role }
  end
end
