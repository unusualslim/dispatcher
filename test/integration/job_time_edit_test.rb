require 'test_helper'

class JobTimeEditTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: 'admin-jobedit@example.com', password: 'password123', role: 'admin')
    @worker = User.create!(email: 'worker-jobedit@example.com', password: 'password123', role: 'line_worker',
                           first_name: 'Line', last_name: 'Worker')
    @po = ProductionOrder.create!
    start = Time.zone.local(2026, 10, 24, 7, 0)
    @job = @po.jobs.create!(created_by: @admin, job_type: 'Filling', started_at: start, ended_at: start + 10.minutes)
    @jw = @job.job_workers.create!(user: @worker, clocked_in_at: start, clocked_out_at: start + 10.minutes)
  end

  def times(clock_in, clock_out)
    { job_workers: { @jw.id.to_s => { clocked_in_at: clock_in, clocked_out_at: clock_out } } }
  end

  test 'admin corrects clock times and costing uses the new hours' do
    sign_in @admin
    get job_path(@job)
    assert_select '.card-header', 'Edit Clock Times'

    patch job_path(@job), params: times('2026-10-24T07:00', '2026-10-24T15:30')
    assert_redirected_to job_path(@job)

    assert_in_delta 8.5, @jw.reload.hours, 0.001
    assert_equal Time.zone.local(2026, 10, 24, 15, 30), @job.reload.ended_at
    assert_equal @admin, @job.edited_by
    assert_in_delta 8.5, ProductionOrderCosting.new(@po).actual_labor_hours, 0.001
  end

  test 'clock out must be after clock in' do
    sign_in @admin
    patch job_path(@job), params: times('2026-10-24T15:00', '2026-10-24T07:00')

    assert_match 'must be after clocking in', flash[:alert]
    assert_in_delta 10.0 / 60, @jw.reload.hours, 0.001
  end

  test 'line workers cannot edit times' do
    sign_in @worker
    patch job_path(@job), params: times('2026-10-24T07:00', '2026-10-24T15:30')

    assert_in_delta 10.0 / 60, @jw.reload.hours, 0.001
  end

  test 'running jobs are clocked out before editing' do
    @job.update!(ended_at: nil)
    sign_in @admin
    patch job_path(@job), params: times('2026-10-24T07:00', '2026-10-24T15:30')

    assert_match 'Clock the crew out', flash[:alert]
  end
end
