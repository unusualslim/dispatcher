require 'test_helper'

# Time-phased MRP: a finished good (2 RAW per FG) runs short, its suggested production pushes demand onto
# the raw material, which then runs out before its purchase order arrives.
module Mrp
  class PlanTest < ActiveSupport::TestCase
    setup do
      @today = Date.new(2026, 11, 2)
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      ReportingGroup.find_or_create_by!(name: 'MRP Packaged') { |g| g.item_type = 'warehouse' }
      ReportingGroup.find_or_create_by!(name: 'MRP Fuel') { |g| g.item_type = 'fuel' }
      @vendor = Vendor.create!(id: 'V-MRP', name: 'MRP Supply Co', lead_time_days: 5)
      @raw = Product.create!(id: 'MRP-RAW', name: 'Urea', is_raw_material: true, current_stock: 100)
      @raw.product_vendors.create!(vendor: @vendor, priority: 1)
      @fg = Product.create!(id: 'MRP-FG', name: 'DEF 2.5 gal', category: 'MRP Packaged', current_stock: 10)
      ProductComponent.create!(product: @fg, component_product: @raw, quantity_per_unit: 2)
      @fuel = Product.create!(id: 'MRP-FUEL', name: 'Diesel', category: 'MRP Fuel', current_stock: 0)
      @yard = Location.create!(company_name: 'MRP Yard', location_category_id: 2)
      @customer = Customer.create!(name: 'MRP Customer', preferred_contact_method: 'no preference', lead_time_days: 4)
    end

    def order(product, qty, date: nil, status: 'open_order', order_date: nil)
      order = CustomerOrder.create!(customer: @customer, location: @yard, order_status: status,
                                    required_delivery_date: date, order_date: order_date)
      order.customer_order_products.create!(product_id: product.id, product_name: product.id, quantity: qty)
    end

    def run_plan
      Mrp::Plan.new(today: @today).run
    end

    test 'finds when each product runs out, why, and what to do by when' do
      production = ProductionOrder.create!(number: 'MRP-1', status: 'created', product: @fg, qty_to_make: 35,
                                           production_date: @today + 5, due_date: @today + 6)
      production.production_order_components.create!(product: @raw, quantity: 70)
      order(@fg, 60, date: @today + 10)
      order(@raw, 15, date: @today + 7)
      po = PurchaseOrder.create!(vendor: @vendor, status: 'submitted', expected_delivery_date: @today + 12)
      po.line_items.create!(product: @raw, quantity: 50, unit_cost: 1)
      order(@fg, 999, date: @today + 3, status: 'quote')

      result = run_plan
      fg = result.plans['MRP-FG']
      raw = result.plans['MRP-RAW']

      # FG: 10 + 35 (production, day 6) - 60 (day 10) = -15 → produce 15, starting a day early.
      assert_equal @today + 10, fg.runs_out_on
      assert_equal([[:planned_production, 15, @today + 10, @today + 9]],
                   fg.suggestions.map { |s| [s.kind, s.qty.to_i, s.need_date, s.act_by] })

      # RAW: 100 - 70 (day 5) - 15 (day 7) - 30 (planned production, day 9) = -15 → buy 15, 5-day lead time.
      assert_equal @today + 9, raw.runs_out_on
      assert_equal([[:planned_purchase, 15, @today + 9, @today + 4]],
                   raw.suggestions.map { |s| [s.kind, s.qty.to_i, s.need_date, s.act_by] })
      assert_equal [po.id], raw.expedite.map { |e| e.path[/\d+\z/].to_i }, 'PO arrives after it runs out'
      assert_includes raw.causes.map(&:kind), :planned_component

      assert_equal(%w[MRP-RAW MRP-FG], result.actions.map { |p| p.product.id }.select { |id| id.start_with?('MRP-') })
      assert_not result.plans.key?('MRP-FUEL'), 'fuel is left to the tank inventory report'
    end

    test 'dates undated orders by the customer lead time and flags overdue orders and late POs' do
      order(@raw, 30, order_date: @today - 1)
      order(@raw, 5, date: @today - 3)
      late = PurchaseOrder.create!(vendor: @vendor, status: 'submitted', expected_delivery_date: @today - 2)
      late.line_items.create!(product: @raw, quantity: 1, unit_cost: 1)

      events = run_plan.plans['MRP-RAW'].rows.map(&:event)

      assert_equal @today + 3, events.find { |e| e.qty == -30 }.date, 'order date + customer lead time (4 days)'
      assert_equal([@today, [:overdue]], events.find { |e| e.qty == -5 }.then { |e| [e.date, e.flags] })
      assert_equal [:late], events.find { |e| e.kind == :purchase }.flags
    end

    test 'plans below safety stock and uses the product lead time over the vendor' do
      @raw.update!(safety_stock: 50, lead_time_days: 10)
      order(@raw, 60, date: @today + 20)

      raw = run_plan.plans['MRP-RAW']

      assert_nil raw.runs_out_on
      assert_equal @today + 20, raw.below_safety_on
      assert_equal([[10, @today + 10]], raw.suggestions.map { |s| [s.qty.to_i, s.act_by] })
    end
  end
end
