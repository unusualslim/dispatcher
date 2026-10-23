require 'test_helper'

# Announcements use the rich-text editor; their content must render as HTML, not escaped markup.
class AnnouncementRichTextTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'announcement content saved from the editor renders as rich text' do
    sign_in User.create!(email: 'admin-announce@example.com', password: 'password123', role: 'admin')

    post announcements_path, params: { announcement: {
      title: 'Holiday hours', status: 'active', published_at: Time.current,
      content: '<div>Closed <strong>Monday</strong></div>'
    } }
    announcement = Announcement.order(:id).last
    assert_redirected_to announcement_path(announcement)

    get announcement_path(announcement)
    assert_response :success
    assert_select '.trix-content strong', 'Monday'
    assert_no_match '&lt;strong&gt;', response.body
  end
end
