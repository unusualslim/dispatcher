require 'test_helper'

# Equipment (packaging lines, forklifts...) shares the things table with trucks and trailers but must never show up
# in the dispatch truck / trailer pickers.
class DispatchVehiclePickersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'truck and trailer pickers list only trucks and trailers' do
    Thing.create!(name: 'Truck 12', category: 'truck')
    Thing.create!(name: 'Trailer 7', category: 'trailer')
    Thing.create!(name: 'Kaps-All Capper', category: 'equipment')
    sign_in User.create!(email: 'admin-pickers@example.com', password: 'password123', role: 'admin')

    get new_dispatch_path

    assert_response :success
    assert_select 'select[name="dispatch[truck_id]"] option', text: 'Truck 12'
    assert_select 'select[name="dispatch[trailer_id]"] option', text: 'Trailer 7'
    assert_select 'option', text: 'Kaps-All Capper', count: 0
    assert_select 'select[name="dispatch[truck_id]"] option', text: 'Trailer 7', count: 0
  end
end
