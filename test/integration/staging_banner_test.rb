require 'test_helper'

# The staging copy (STAGING=1) shows a banner and marks the tab title; production never does.
class StagingBannerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in User.create!(email: 'staging-banner@example.com', password: 'password123', role: 'admin') }
  teardown { Rails.configuration.x.staging = nil }

  test 'no banner outside staging' do
    get expense_accounts_path
    assert_select '.staging-banner', 0
    assert_select 'title', text: 'FPS Team'
  end

  test 'staging shows the banner with the copy date' do
    Rails.configuration.x.staging = true
    AppSetting.set('staging_refreshed_at', '2026-11-03 21:00')
    get expense_accounts_path
    assert_select '.staging-banner', text: /copy of production from 2026-11-03 21:00/
    assert_select 'title', text: 'STAGING · FPS Team'
  end
end
