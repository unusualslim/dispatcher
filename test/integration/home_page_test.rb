require 'test_helper'

# Per-user home pages: where sign-in, "/" and the logo go.
class HomePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def staff(email, permissions, home_page: nil)
    User.create!(email: email, password: 'password123', role: 'staff', permissions: permissions, home_page: home_page)
  end

  test 'signing in and / go to the chosen home page, else the role default' do
    user = staff('home-staff@example.com', { 'sales' => 'view', 'purchasing' => 'view' }, home_page: '/mrp')

    post user_session_path, params: { user: { email: user.email, password: 'password123' } }
    assert_redirected_to '/mrp'
    get '/'
    assert_redirected_to '/mrp'

    user.update!(home_page: nil)
    get '/'
    assert_redirected_to dashboard_customer_orders_path
  end

  test 'users set their own home page; only paths inside the app are accepted' do
    user = staff('home-set@example.com', { 'dispatch' => 'view' })
    sign_in user

    patch home_page_path, params: { path: '/calendar' }, as: :json
    assert_response :success
    assert_equal '/calendar', user.reload.home_page

    ['https://evil.example', '//evil.example', 'mrp'].each do |bad|
      patch home_page_path, params: { path: bad }, as: :json
      assert_response :unprocessable_content
    end
    assert_equal '/calendar', user.reload.home_page

    patch home_page_path, params: { path: '' }
    assert_nil user.reload.home_page
  end

  test 'a home page the user can no longer see falls back to the default without looping' do
    user = staff('home-lost@example.com', { 'sales' => 'view' }, home_page: '/mrp')
    sign_in user

    get '/'
    assert_redirected_to '/mrp'
    follow_redirect!
    assert_redirected_to dashboard_customer_orders_path
  end

  test 'drivers keep their fixed home and cannot choose one' do
    driver = User.create!(email: 'home-driver@example.com', password: 'password123', role: 'worker', home_page: '/mrp')
    sign_in driver

    get '/'
    assert_redirected_to dispatches_path
    patch home_page_path, params: { path: '/calendar' }
    assert_equal '/mrp', driver.reload.home_page # unchanged, and ignored for drivers
  end

  test 'admins set a user home page on the Users form and see it offered on My Account' do
    user = staff('home-admin-set@example.com', { 'production' => 'view' })
    sign_in User.create!(email: 'home-admin@example.com', password: 'password123', role: 'admin')

    get edit_user_path(user)
    assert_select 'select[name="user[home_page]"] option[value="/production_orders/kanban"]'
    assert_select 'select[name="user[home_page]"] option[value="/mrp"]', count: 0 # no purchasing access

    patch user_path(user), params: { user: { home_page: '/production_orders/kanban' } }
    assert_equal '/production_orders/kanban', user.reload.home_page

    sign_in user
    get edit_user_registration_path
    assert_select 'select[name=path] option[selected][value="/production_orders/kanban"]'
  end
end
