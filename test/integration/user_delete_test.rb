require 'test_helper'

# Deleting users vs. deactivating them.
class UserDeleteTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: 'admin-del@example.com', password: 'password123', role: 'admin')
    sign_in @admin
  end

  test 'users with line clock history are kept, with a reason' do
    worker = User.create!(email: 'line-del@example.com', password: 'password123', role: 'line_worker',
                          first_name: 'Pat', last_name: 'Line')
    job = ProductionOrder.create!.jobs.create!(created_by: @admin, job_type: 'Filling', started_at: Time.current)
    job.job_workers.create!(user: worker, clocked_in_at: Time.current)

    delete user_path(worker)

    assert User.exists?(worker.id)
    assert_match 'Pat Line has history in the app (line clock records)', flash[:alert]
  end

  test 'users with no history can be deleted' do
    user = User.create!(email: 'temp-del@example.com', password: 'password123', role: 'staff')
    delete user_path(user)

    assert_not User.exists?(user.id)
  end

  test 'deactivated users keep their history, cannot sign in, and leave pickers' do
    driver = User.create!(email: 'old-driver@example.com', password: 'password123', role: 'worker', first_name: 'Old')

    patch deactivate_user_path(driver)
    assert_not driver.reload.active?
    assert_not_includes User.workers, driver
    assert_not driver.active_for_authentication?

    get users_path
    assert_select 'h6', /Inactive \(1\)/

    patch reactivate_user_path(driver)
    assert driver.reload.active?
  end

  test 'admins cannot deactivate themselves' do
    patch deactivate_user_path(@admin)
    assert @admin.reload.active?
  end

  test 'a deactivated user is signed out on their next request' do
    driver = User.create!(email: 'gone-driver@example.com', password: 'password123', role: 'worker')
    sign_in driver
    driver.update!(deactivated_at: Time.current)

    get dispatches_path
    assert_redirected_to new_user_session_path
  end
end
