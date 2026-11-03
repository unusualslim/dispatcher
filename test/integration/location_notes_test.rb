require 'test_helper'

# Location notes are plain text; line breaks typed into them have to survive on screen.
class LocationNotesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'notes keep their line breaks on the location page' do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    location = Location.create!(company_name: 'Notes Terminal', location_category_id: 1)
    sign_in User.create!(email: 'notes-admin@example.com', password: 'password123', role: 'admin')

    patch location_path(location), params: { location: { notes: "Gate code 1234\nCall ahead" } }
    assert_redirected_to location_path(location)
    assert_equal "Gate code 1234\nCall ahead", location.reload.notes

    get location_path(location)
    assert_select '.pre-line', text: "Gate code 1234\nCall ahead"
  end
end
