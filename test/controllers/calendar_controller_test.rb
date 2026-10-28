require 'test_helper'

class CalendarControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'calendar-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'should get index' do
    get calendar_url
    assert_response :success
  end

  test 'should get events' do
    get calendar_events_url, params: { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
    assert_response :success
  end
end
