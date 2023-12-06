# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!

# Configure ActionMailer to use SendGrid
ActionMailer::Base.smtp_settings = {
    :user_name => ENV['SENDGRID_USERNAME'], # This is the string literal 'apikey', NOT the ID of your API key
    :password => ENV['SENDGRID_PASSWORD'],
    :domain => 'dispatcher.com',
    :address => 'smtp.sendgrid.net',
    :port => 587,
    :authentication => :plain,
    :enable_starttls_auto => true
  }
