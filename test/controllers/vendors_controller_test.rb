require 'test_helper'

class VendorsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'vendors-admin@example.com', password: 'password123', role: 'admin')
    @vendor = Vendor.create!(id: '9001', name: 'Test Vendor Co')
  end

  test 'should get index' do
    get vendors_url
    assert_response :success
    assert_select "form[action='#{vendors_path}'][method='post']", 0 # vendors come from PDI, no add form
  end

  test 'should show vendor' do
    get vendor_url(@vendor)
    assert_response :success
  end

  test 'should update vendor' do
    patch vendor_url(@vendor), params: { vendor: { lead_time_days: 5 } }
    assert_equal 5, @vendor.reload.lead_time_days
  end

  test 'should destroy vendor' do
    assert_difference('Vendor.count', -1) do
      delete vendor_url(@vendor)
    end
    assert_redirected_to vendors_url
  end
end
