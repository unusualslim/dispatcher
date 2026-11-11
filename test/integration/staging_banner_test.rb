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
    assert_select '.main-wrapper > .staging-banner', text: /copy of production from 2026-11-03 21:00/
    assert_select 'title', text: 'STAGING · FPS Team'
  end

  test 'production links staging for the team; staging does not link itself' do
    get expense_accounts_path
    assert_select '.sidebar-footer a[href="https://dispatcher-staging.onrender.com"][target="_blank"]', text: /Staging/

    Rails.configuration.x.staging = true
    get expense_accounts_path
    assert_select '.sidebar-footer a[href="https://dispatcher-staging.onrender.com"]', 0
  end

  test 'drivers do not get the staging link' do
    sign_out :user
    sign_in User.create!(email: 'staging-driver@example.com', password: 'password123', role: 'worker')
    get '/'
    follow_redirect! while response.redirect?
    assert_select '.sidebar-footer'
    assert_select 'a[href="https://dispatcher-staging.onrender.com"]', 0
  end
end
