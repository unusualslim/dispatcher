#!/usr/bin/env bash
# exit on error
set -o errexit

apt-get install -y poppler-utils

bundle install
bundle exec rake assets:precompile RAILS_ENV=production
bundle exec rake assets:clean
bundle exec rake db:migrate