require 'test_helper'

class MaterialReadinessTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    @plant = Location.create!(company_name: 'MR Plant', location_category_id: 1)
    @other = Location.create!(company_name: 'MR Other', location_category_id: 1)
    @urea = Product.create!(id: 'MR-UREA', name: 'Urea', is_raw_material: true)
    @jug = Product.create!(id: 'MR-JUG', name: 'Jug', is_raw_material: true)
    LocationProduct.create!(product: @urea, location: @plant, quantity: 100)
    LocationProduct.create!(product: @urea, location: @other, quantity: 1000) # not where it's made
    LocationProduct.create!(product: @jug, location: @plant, quantity: 500)
    @vendor = Vendor.create!(id: 'V-MR', name: 'MR Supply')
  end

  def production(number, day, components, status: 'created', location: @plant)
    order = ProductionOrder.create!(number: number, status: status, location: location,
                                    production_date: Date.current + day,
                                    due_date: Date.current + day + 1)
    components.each { |product, qty| order.production_order_components.create!(product: product, quantity: qty) }
    order
  end

  test 'earlier needs take the stock first: green, then yellow on incoming supply, then red' do
    first = production('MR-1', 2, [[@urea, 60], [@jug, 10]])
    second = production('MR-2', 5, [[@urea, 60]])
    third = production('MR-3', 6, [[@urea, 30]])
    po = PurchaseOrder.create!(vendor: @vendor, status: 'submitted', expected_delivery_date: Date.current + 4,
                               location: @plant)
    po.line_items.create!(product: @urea, quantity: 30, unit_cost: 1)

    readiness = MaterialReadiness.new([first, second, third])
    level = ->(order) { readiness.component(order.production_order_components.find_by!(product: @urea)).level }

    assert_equal :green, level.call(first)
    assert_equal :yellow, level.call(second), '100 on hand - 60 earlier; needs the PO'
    assert_equal :red, level.call(third)
    assert_match(/Short 20 by/, readiness.component(third.production_order_components.first).reason)
    assert_equal(%i[green yellow red], [first, second, third].map { |o| readiness.order(o).level })
  end

  test 'late POs, safety stock, unlinked components and missing warehouses are yellow; finished orders get no dots' do
    @urea.update!(safety_stock: 50)
    @other.location_products.find_by!(product: @urea).update!(quantity: 1) # the plant is now the main warehouse
    safe = production('MR-4', 1, [[@urea, 60]])
    nowhere = production('MR-7', 1, [[@jug, 1]], location: nil)
    unlinked = ProductionOrder.create!(number: 'MR-5', status: 'created', production_date: Date.current)
    unlinked.production_order_components.create!(description: 'Mystery additive', quantity: 1)
    done = production('MR-6', 1, [[@jug, 9999]], status: 'quality_check') # past in_progress: materials used

    readiness = MaterialReadiness.new([safe, unlinked, done, nowhere])

    assert_equal(['yellow', 'In stock, but leaves less than safety stock'],
                 readiness.order(safe).then { |s| [s.level.to_s, s.reason] })
    assert_equal 'Not linked to a product', readiness.order(unlinked).reason
    assert_nil readiness.order(done)
    assert_equal 'No warehouse set on this production order', readiness.order(nowhere).reason
  end
end
