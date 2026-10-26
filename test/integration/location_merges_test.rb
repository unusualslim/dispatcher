require 'test_helper'

class LocationMergesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    customer = Customer.create!(name: 'Lm Customer', preferred_contact_method: 'no preference')
    @keep = Location.create!(company_name: 'Lm Yard', city: 'Albany', zip: '31701', location_category_id: 2)
    @dupe = Location.create!(company_name: 'Lm Yard (old)', city: 'Albany', zip: '31701-1234', location_category_id: 2)
    customer.locations << [@keep, @dupe]
    CustomerOrder.create!(customer: customer, location: @keep, order_status: 'billed')
  end

  test 'admin merges a suggested duplicate from the list, and from a location page' do
    sign_in User.create!(email: 'admin-lm@example.com', password: 'password123', role: 'admin')

    get location_merges_path
    assert_select 'a[href=?]', new_location_merge_path(source_id: @dupe.id, target_id: @keep.id)

    get new_location_merge_path(source_id: @dupe.id, target_id: @keep.id)
    assert_response :success
    assert_includes response.body, 'Merge — Lm Yard (old) will be deleted'

    post location_merges_path, params: { source_id: @dupe.id, target_id: @keep.id, return_to: 'location' }
    assert_redirected_to location_path(@keep)
    assert_not Location.exists?(@dupe.id)
  end

  test 'admin merges ticked pairs in bulk; 95%+ pairs come pre-ticked' do
    sign_in User.create!(email: 'admin-bulk@example.com', password: 'password123', role: 'admin')
    @dupe.update!(company_name: 'Lm Yard', address: '1 Main St')
    @keep.update!(address: '1 Main St.')

    get location_merges_path
    assert_select "input.pair-select[value='#{@dupe.id}:#{@keep.id}'][checked]"

    post bulk_location_merges_path, params: { pairs: ["#{@dupe.id}:#{@keep.id}"] }
    assert_redirected_to location_merges_path
    assert_match(/Merged 1 location/, flash[:notice])
    assert_not Location.exists?(@dupe.id)
  end

  test 'staff cannot merge locations' do
    sign_in User.create!(email: 'staff-lm@example.com', password: 'password123', role: 'staff',
                         permissions: { 'dispatch' => 'approve' })
    post location_merges_path, params: { source_id: @dupe.id, target_id: @keep.id }
    assert Location.exists?(@dupe.id)
  end
end
