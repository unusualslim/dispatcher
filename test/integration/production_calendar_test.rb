require 'test_helper'

# Production → Kanban as a production calendar: days by production date, behind schedule, unscheduled.
class ProductionCalendarTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @product = Product.create!(id: 'CAL-1', name: 'Calendar Coolant')
    make = lambda { |number, attrs|
      ProductionOrder.create!({ number: number, product: @product, status: 'created', qty_to_make: 10 }.merge(attrs))
    }
    @today = make.call('CAL-TODAY', production_date: Date.current)
    @behind = make.call('CAL-BEHIND', production_date: Date.current - 5)
    @loose = make.call('CAL-LOOSE', production_date: nil, due_date: Date.current + 3)
    make.call('CAL-DONE-OLD', production_date: Date.current - 5, status: 'completed')
    voided = make.call('CAL-VOID', production_date: Date.current)
    voided.update_columns(status: 'voided') # rubocop:disable Rails/SkipsModelValidations
  end

  test 'shows each day, the orders behind schedule and the unscheduled ones' do
    sign_in User.create!(email: 'cal-admin@example.com', password: 'password123', role: 'admin')
    get kanban_production_orders_path

    assert_response :success
    assert_select 'h1', 'Production Calendar'
    assert_select '.production-col', 10 # behind + 8 days + unscheduled
    assert_select '.production-col:first-child strong', 'Behind schedule'
    assert_select '.production-col:first-child a', text: 'CAL-BEHIND'
    assert_select '.production-col:last-child a', text: 'CAL-LOOSE'
    assert_select 'a', text: 'CAL-TODAY'
    assert_select 'a', text: 'CAL-DONE-OLD', count: 0
    assert_select 'a', text: 'CAL-VOID', count: 0
  end

  test 'an unscheduled order is put on a day from the calendar' do
    sign_in User.create!(email: 'cal-admin2@example.com', password: 'password123', role: 'admin')
    patch schedule_production_order_path(@loose), params: { production_date: (Date.current + 2).iso8601 }

    assert_redirected_to kanban_production_orders_path
    assert_equal Date.current + 2, @loose.reload.production_date
  end

  test 'viewers see the calendar but cannot reschedule' do
    sign_in staff_user('cal-view@example.com', { 'production' => 'view' })
    get kanban_production_orders_path
    assert_response :success
    assert_select 'details summary', count: 0

    patch schedule_production_order_path(@loose), params: { production_date: Date.current.iso8601 }
    assert_nil @loose.reload.production_date
  end
end
