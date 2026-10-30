require 'test_helper'
require 'minitest/mock'

# Sign-up is admin-only (it's how admins add users) and users can't change their own role.
class UserRegistrationSecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin  = User.create!(email: 'admin-reg@example.com', password: 'password123', role: 'admin')
    @driver = User.create!(email: 'driver-reg@example.com', password: 'password123', role: 'worker')
  end

  def sign_up_params(role: 'admin')
    { user: { email: 'new-user@example.com', password: 'password123', password_confirmation: 'password123',
              first_name: 'New', role: role },
      'cf-turnstile-response' => 'token' }
  end

  # Pretends Cloudflare Turnstile approved the request.
  def with_turnstile_passing(&)
    response = Struct.new(:body).new('{"success":true}')
    ENV['TURNSTILE_SECRET_KEY'] = 'test-secret'
    Net::HTTP.stub(:post_form, response, &)
  ensure
    ENV.delete('TURNSTILE_SECRET_KEY')
  end

  test 'signed-out visitors cannot open sign-up' do
    get new_user_registration_path
    assert_response :redirect
  end

  test 'signed-out visitors cannot create an account' do
    with_turnstile_passing do
      assert_no_difference('User.count') { post user_registration_path, params: sign_up_params }
    end
  end

  test 'non-admins cannot create an account' do
    sign_in @driver
    with_turnstile_passing do
      assert_no_difference('User.count') { post user_registration_path, params: sign_up_params }
    end
  end

  test 'admins can create an account and stay signed in as themselves' do
    sign_in @admin
    with_turnstile_passing do
      assert_difference('User.count', 1) { post user_registration_path, params: sign_up_params(role: 'worker') }
    end
    assert_redirected_to users_path
    get users_path
    assert_response :success
  end

  test 'users cannot change their own role from their profile' do
    sign_in @driver
    put user_registration_path, params: { user: { role: 'admin', current_password: 'password123' } }
    assert_equal 'worker', @driver.reload.role
  end

  test 'a sign-up with no Turnstile token says the check did not load' do
    sign_in @admin
    params = sign_up_params
    params.delete('cf-turnstile-response')

    assert_no_difference('User.count') { post user_registration_path, params: params }
    assert_response :unprocessable_content
    assert_match 'security check didn&#39;t load', response.body
  end
end
