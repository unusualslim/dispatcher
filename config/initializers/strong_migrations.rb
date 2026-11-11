# Mark existing migrations as safe
StrongMigrations.start_after = 20261111150252 # rubocop:disable Style/NumericLiterals -- migration timestamp

# Set timeouts for migrations
# If you use PgBouncer in transaction mode, delete these lines and set timeouts on the database user
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Outdated statistics can sometimes hurt performance
StrongMigrations.auto_analyze = true

# Set the version of the production database
# so the right checks are run in development
# Production (Render) runs Postgres 15; check against it even though dev may run newer.
StrongMigrations.target_version = 15

# Add custom checks
# StrongMigrations.add_check do |method, args|
#   if method == :add_index && args[0].to_s == "users"
#     stop! "No more indexes on the users table"
#   end
# end

# Remove invalid indexes when rerunning migrations
# StrongMigrations.remove_invalid_indexes = true

# Make some operations safe by default
# See https://github.com/ankane/strong_migrations#safe-by-default
# StrongMigrations.safe_by_default = true
