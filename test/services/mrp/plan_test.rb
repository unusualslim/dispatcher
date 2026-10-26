require 'test_helper'

# Time-phased MRP per warehouse: a finished good (2 RAW per FG) runs short, its suggested production
# pushes demand onto the raw material at the same warehouse, which runs out before its PO arrives.
module Mrp
  class PlanTest < ActiveSupport::TestCase
    setup do
      @today = Date.new(2026, 11, 2)
      LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      ReportingGroup.find_or_create_by!(name: 'MRP Packaged') { |g| g.item_type = 'warehouse' }
      ReportingGroup.find_or_create_by!(name: 'MRP Fuel') { |g| g.item_type = 'fuel' }
      @main = Location.create!(company_name: 'MRP Main', location_category_id: 1, pdi_site_code: '9002')
      @south = Location.create!(company_name: 'MRP South', location_category_id: 1, pdi_site_code: '9110')
      @vendor = Vendor.create!(id: 'V-MRP', name: 'MRP Supply Co', lead_time_days: 5)
      @raw = Product.create!(id: 'MRP-RAW', name: 'Urea', is_raw_material: true)
      @raw.product_vendors.create!(vendor: @vendor, priority: 1)
      @fg = Product.create!(id: 'MRP-FG', name: 'DEF 2.5 gal', category: 'MRP Packaged')
      ProductComponent.create!(product: @fg, component_product: @raw, quantity_per_unit: 2)
      @fuel = Product.create!(id: 'MRP-FUEL', name: 'Diesel', category: 'MRP Fuel')
      stock(@raw, @main, 100)
      stock(@fg, @main, 10)
      @yard = Location.create!(company_name: 'MRP Yard', location_category_id: 2)
      @customer = Customer.create!(name: 'MRP Customer', preferred_contact_method: 'no preference', lead_time_days: 4)
    end

    def stock(product, location, qty)
      LocationProduct.create!(product: product, location: location, quantity: qty)
    end

    # opts: date:, status:, order_date:, warehouse: (default the main warehouse), site: (PDI site ID)
    def order(product, qty, **opts)
      order = CustomerOrder.create!(customer: @customer, location: @yard, required_delivery_date: opts[:date],
                                    order_status: opts.fetch(:status, 'open_order'), order_date: opts[:order_date])
      order.customer_order_products.create!(product_id: product.id, product_name: product.id, quantity: qty,
                                            location: opts.fetch(:warehouse, @main), warehouse: opts[:site])
    end

    def run_plan
      Mrp::Plan.new(today: @today).run
    end

    def summary(plan)
      plan.suggestions.map { |s| [s.kind, s.qty.to_i, s.need_date, s.act_by] }
    end

    test 'finds when each product runs out at a warehouse, why, and what to do by when' do
      production = ProductionOrder.create!(number: 'MRP-1', status: 'created', product: @fg, qty_to_make: 35,
                                           production_date: @today + 5, due_date: @today + 6, location: @main)
      production.production_order_components.create!(product: @raw, quantity: 70)
      order(@fg, 60, date: @today + 10)
      order(@raw, 15, date: @today + 7)
      po = PurchaseOrder.create!(vendor: @vendor, status: 'submitted', expected_delivery_date: @today + 12,
                                 location: @main)
      po.line_items.create!(product: @raw, quantity: 50, unit_cost: 1)
      order(@fg, 999, date: @today + 3, status: 'quote')

      result = run_plan
      fg = result.plans[['MRP-FG', @main.id]]
      raw = result.plans[['MRP-RAW', @main.id]]

      # FG: 10 + 35 (production, day 6) - 60 (day 10) = -15 → produce 15, starting a day early.
      assert_equal @today + 10, fg.runs_out_on
      assert_equal [[:planned_production, 15, @today + 10, @today + 9]], summary(fg)
      # RAW: 100 - 70 (day 5) - 15 (day 7) - 30 (planned production, day 9) = -15 → buy 15, 5-day lead time.
      assert_equal @today + 9, raw.runs_out_on
      assert_equal [[:planned_purchase, 15, @today + 9, @today + 4]], summary(raw)
      assert_equal [po.id], raw.expedite.map { |e| e.path[/\d+\z/].to_i }, 'PO arrives after it runs out'
      assert_includes raw.causes.map(&:kind), :planned_component

      assert_equal %w[MRP-RAW MRP-FG], result.actions(@main.id).map { |p| p.product.id }.grep(/\AMRP-/)
      assert_not result.plans.key?(['MRP-FUEL', nil]), 'fuel is left to the tank inventory report'
    end

    test 'transfers spare stock from another warehouse before ordering the rest' do
      stock(@raw, @south, 40)
      order(@raw, 30, date: @today + 20, warehouse: @south) # South keeps 10 spare
      order(@raw, 125, date: @today + 10)                   # Main is 25 short

      result = run_plan
      main = result.plans[['MRP-RAW', @main.id]]
      south = result.plans[['MRP-RAW', @south.id]]

      assert_equal([10], main.transfers_in.map { |e| e.qty.to_i })
      assert_equal [[:planned_purchase, 15, @today + 10, @today + 5]], summary(main)
      assert_empty south.suggestions, 'the donor keeps enough for its own orders'
      assert_equal 0, south.rows.last.balance
    end

    test 'skips dropship lines, lists lines without a warehouse, and dates undated orders by the customer' do
      order(@raw, 500, date: @today + 2, warehouse: nil, site: '7777')
      order(@raw, 7, date: @today + 2, warehouse: nil)
      order(@raw, 30, order_date: @today - 1)
      late = PurchaseOrder.create!(vendor: @vendor, status: 'submitted', expected_delivery_date: @today - 2,
                                   location: @main)
      late.line_items.create!(product: @raw, quantity: 1, unit_cost: 1)

      result = run_plan
      events = result.plans[['MRP-RAW', @main.id]].rows.map(&:event)

      assert_equal([-7], result.unassigned.select { |p, _| p == @raw }.map { |_, e| e.qty.to_i })
      assert_not events.any? { |e| e.qty == -500 }, 'dropship never touches our stock'
      assert_equal @today + 3, events.find { |e| e.qty == -30 }.date, 'order date + customer lead time (4 days)'
      purchase = events.find { |e| e.kind == :purchase }
      assert_equal [[:late], @today - 2], [purchase.flags, purchase.original_date]
    end

    test 'holds safety stock at the main warehouse and uses the product lead time over the vendor' do
      @raw.update!(safety_stock: 50, lead_time_days: 10)
      order(@raw, 60, date: @today + 20)

      raw = run_plan.plans[['MRP-RAW', @main.id]]

      assert_nil raw.runs_out_on
      assert_equal @today + 20, raw.below_safety_on
      assert_equal [[:planned_purchase, 10, @today + 20, @today + 10]], summary(raw)
    end
  end
end
