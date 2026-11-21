require 'test_helper'

# Sidebar groups hold daily links, then Reports / Review / Setup subgroups that fold away.
class SidebarTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'a report opens its group and its Reports subgroup' do
    sign_in User.create!(email: 'sidebar-admin@example.com', password: 'password123', role: 'admin')
    report = Reports::Registry::REPORTS.find { |r| r.area.to_s == 'sales' }

    get report_path(report.key)

    assert_response :success
    assert_select '#salesCollapse.show #salesReportsCollapse.show li.active a[href=?]', report_path(report.key)
    assert_select '#salesReportsCollapse', count: 1
    assert_select '#salesSetupCollapse:not(.show) a[href=?]', customers_path
    assert_select '#dispatchSetupCollapse a[href=?]', edit_samsara_settings_path
    assert_select '#productionSetupCollapse a[href=?]', things_path
    assert_select '#dispatchSetupCollapse a[href=?]', things_path
    assert_select '#adminDataCollapse a[href=?]', imports_path
    # Dispatch and Accounting have no reports yet, so no empty Reports subgroup
    assert_select '#dispatchReportsCollapse', count: 0
  end

  test 'setup pages open their subgroup' do
    sign_in User.create!(email: 'sidebar-admin2@example.com', password: 'password123', role: 'admin')

    get scrap_reasons_path

    assert_select '#productionCollapse.show #productionSetupCollapse.show li.active a[href=?]', scrap_reasons_path
    assert_select 'button.sidebar-subgroup-toggle.has-active[data-bs-target="#productionSetupCollapse"]'
  end

  test 'staff only see subgroups and links they have access to' do
    sign_in staff_user('sidebar-staff@example.com', { 'sales' => 'view', 'dispatch' => 'view' }, flags: [])

    get customers_path

    assert_response :success
    assert_select '#salesSetupCollapse.show li.active a[href=?]', customers_path
    assert_select '#salesReviewCollapse', count: 0 # both review pages need data flags
    assert_select '#dispatchSetupCollapse a[href=?]', feed_tanks_path
    assert_select 'a[href=?]', edit_samsara_settings_path, count: 0
    assert_select 'a[href=?]', things_path, count: 0
    assert_select '#productionCollapse', count: 0
  end
end
