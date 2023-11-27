require "test_helper"

class DispatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dispatch = dispatches(:one)
  end

  test "should get index" do
    get dispatches_url
    assert_response :success
  end

  test "should get new" do
    get new_dispatch_url
    assert_response :success
  end

  test "should create dispatch" do
    assert_difference("Dispatch.count") do
      post dispatches_url, params: { dispatch: { dispatch_date: @dispatch.dispatch_date, driver_id: @dispatch.driver_id, info: @dispatch.info, notes: @dispatch.notes, origin: @dispatch.origin, status: @dispatch.status } }
    end

    assert_redirected_to dispatch_url(Dispatch.last)
  end

  test "should show dispatch" do
    get dispatch_url(@dispatch)
    assert_response :success
  end

  test "should get edit" do
    get edit_dispatch_url(@dispatch)
    assert_response :success
  end

  test "should update dispatch" do
    patch dispatch_url(@dispatch), params: { dispatch: { dispatch_date: @dispatch.dispatch_date, driver_id: @dispatch.driver_id, info: @dispatch.info, notes: @dispatch.notes, origin: @dispatch.origin, status: @dispatch.status } }
    assert_redirected_to dispatch_url(@dispatch)
  end

  test "should destroy dispatch" do
    assert_difference("Dispatch.count", -1) do
      delete dispatch_url(@dispatch)
    end

    assert_redirected_to dispatches_url
  end
end
