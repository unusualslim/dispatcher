require 'test_helper'

# Signing in and out through the real Devise forms (other tests use the sign_in helper).
class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: 'auth-test@example.com', password: 'password123', role: 'admin')
  end

  test 'sign in with the form, then sign out' do
    get new_user_session_path
    assert_response :success

    post user_session_path, params: { user: { email: @user.email, password: 'password123' } }
    assert_response :see_other
    follow_redirect!
    assert_response :success

    get destroy_user_session_path
    get dispatches_path
    assert_redirected_to new_user_session_path
  end

  test 'a wrong password is refused' do
    post user_session_path, params: { user: { email: @user.email, password: 'wrong-password' } }
    assert_response :unprocessable_content
    get dispatches_path
    assert_redirected_to new_user_session_path
  end

  test 'deactivated users cannot sign in' do
    @user.update!(deactivated_at: Time.current)
    post user_session_path, params: { user: { email: @user.email, password: 'password123' } }
    get dispatches_path
    assert_redirected_to new_user_session_path
  end
end
