require 'test_helper'

class DispatchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'dispatch-admin@example.com', password: 'password123', role: 'admin')
    @dispatch = Dispatch.create!(origin: 'Warehouse', dispatch_date: Date.current, status: 'New', notes: 'Test')
  end

  test 'should get index' do
    get dispatches_url
    assert_response :success
  end

  test 'should get new' do
    get new_dispatch_url
    assert_response :success
  end

  test 'should create dispatch' do
    assert_difference('Dispatch.count') do
      post dispatches_url, params: { dispatch: { dispatch_date: Date.current, origin: 'Warehouse', status: 'New' } }
    end

    assert_redirected_to dispatch_url(Dispatch.last)
  end

  test 'should show dispatch' do
    get dispatch_url(@dispatch)
    assert_response :success
  end

  test 'should get edit' do
    get edit_dispatch_url(@dispatch)
    assert_response :success
  end

  test 'should update dispatch' do
    patch dispatch_url(@dispatch), params: { dispatch: { notes: 'Updated' } }
    assert_redirected_to dispatch_url(@dispatch)
    assert_equal 'Updated', @dispatch.reload.notes
  end

  test 'should destroy dispatch' do
    assert_difference('Dispatch.count', -1) do
      delete dispatch_url(@dispatch)
    end

    assert_redirected_to dispatches_url
  end
end
