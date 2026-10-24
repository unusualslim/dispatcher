require 'test_helper'

class ProductionOrderTest < ActiveSupport::TestCase
  fixtures :users

  test 'new orders start as created' do
    assert_equal 'created', ProductionOrder.create!.status
  end

  test 'the first clock-in moves a created order to in progress' do
    po = ProductionOrder.create!
    po.jobs.create!(created_by: users(:admin_user), job_type: 'Filling', started_at: Time.current)

    assert_equal 'in_progress', po.reload.status
  end

  test 'clocking in does not reopen a completed order' do
    po = ProductionOrder.create!(status: 'completed')
    po.jobs.create!(created_by: users(:admin_user), job_type: 'Cleanup', started_at: Time.current)

    assert_equal 'completed', po.reload.status
  end

  test 'completing stamps the completion date' do
    po = ProductionOrder.create!
    po.update!(status: 'completed')

    assert_equal Time.zone.today, po.date_completed
  end
end
