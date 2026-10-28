require 'test_helper'

# New users are added through the admin-only Devise sign-up (see user_registration_security_test.rb).
class UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'users-admin@example.com', password: 'password123', role: 'admin')
    @user = User.create!(email: 'driver@example.com', password: 'password123', role: 'worker',
                         first_name: 'Dana', last_name: 'Driver')
  end

  test 'should get index' do
    get users_url
    assert_response :success
  end

  test 'should show user' do
    get user_url(@user)
    assert_response :success
  end

  test 'should get edit' do
    get edit_user_url(@user)
    assert_response :success
  end

  test 'should update user' do
    patch user_url(@user), params: { user: { first_name: 'Dan', password: '' } }
    assert_redirected_to users_url
    assert_equal 'Dan', @user.reload.first_name
  end

  test 'should destroy user' do
    assert_difference('User.count', -1) do
      delete user_url(@user)
    end

    assert_redirected_to users_url
  end
end
