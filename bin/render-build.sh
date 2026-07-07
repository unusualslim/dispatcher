#!/usr/bin/env bash
# exit on error
set -o errexit

apt-get update -qq && apt-get install -y --no-install-recommends poppler-utils || true

bundle install
bundle exec rake assets:precompile RAILS_ENV=production
bundle exec rake assets:clean
bundle exec rake db:migrate