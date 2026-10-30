require 'test_helper'

# What's New (/docs/changelog): the feature timeline from docs/feature_timeline.yml above the release notes.
class DocsChangelogTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'shows the feature timeline with an area filter' do
    sign_in User.create!(email: 'changelog-viewer@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'view' })
    get docs_changelog_path
    assert_response :success
    assert_select '#feature-timeline h5', text: 'Dispatcher v1'
    assert_select '#feature-timeline [data-timeline-area=?]', 'Accounting'
    assert_select '.timeline-item[data-area=?]', 'Sales', minimum: 1
    assert_select '.timeline-date', text: /Oct 29, 2026/
  end

  test 'every timeline item uses a known area' do
    timeline = YAML.safe_load_file(Rails.root.join('docs/feature_timeline.yml'), permitted_classes: [Date])
    timeline.flat_map { |era| era['items'] }.each do |item|
      assert_includes DocsController::TIMELINE_AREAS, item['area'], item['title']
      assert_kind_of Date, item['date'], item['title']
    end
  end
end
