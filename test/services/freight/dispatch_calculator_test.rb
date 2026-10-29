require 'test_helper'

module Freight
  class DispatchCalculatorTest < ActiveSupport::TestCase
    setup do
      LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      @terminal = Location.create!(company_name: 'Dfc Terminal', location_category_id: 1)
      @near = Location.create!(company_name: 'Dfc Near', location_category_id: 2)
      @far = Location.create!(company_name: 'Dfc Far', location_category_id: 2)
      FreightLane.create!(origin_location: @terminal, destination_location: @near, standard_miles: 30)
      FreightLane.create!(origin_location: @terminal, destination_location: @far, standard_miles: 80)
      @fpl = Vendor.create!(id: 'DFC-FPL', name: 'Dfc Logistics')
      fc = FreightClass.create!(code: 'DFC', full_load_quantity: 8500)
      @def = Product.create!(id: 'DFC-DEF', name: 'Dfc DEF', freight_class: fc)

      miles = FreightTable.create!(name: 'Dfc miles', lookup_type: 'mileage')
      miles.rates.create!(miles_from: 0, miles_to: 50, rate: 0.05)
      miles.rates.create!(miles_from: 50, rate: 0.08)
      stop = FreightTable.create!(name: 'Dfc stop', lookup_type: 'flat').tap { |t| t.rates.create!(rate: 50) }
      sell = FreightTable.create!(name: 'Dfc sell', lookup_type: 'mileage').tap do |t|
        t.rates.create!(miles_from: 0, rate: 0.10)
      end
      base = { carrier: @fpl, effective_from: Date.new(2026, 1, 1) }
      FreightRule.create!(base.merge(name: 'FPL load', side: 'purchase', basis: 'per_unit', freight_table: miles,
                                     calculation: 'dispatch_farthest'))
      FreightRule.create!(base.merge(name: 'FPL stop', side: 'purchase', charge_type: 'extra_stop', basis: 'per_stop',
                                     freight_table: stop))
      FreightRule.create!(name: 'Sell', side: 'sale', basis: 'per_unit', freight_table: sell,
                          effective_from: Date.new(2026, 1, 1))

      @dispatch = Dispatch.create!(dispatch_date: Date.new(2026, 10, 29), origin: @terminal.full_address_with_company)
      @orders = [[@near, 2000], [@far, 3000], [@near, 1000]].map do |site, gallons|
        order = CustomerOrder.create!(location: site, order_status: 'dispatched', pdi_carrier_id: @fpl.id,
                                      order_date: Date.new(2026, 10, 28))
        order.customer_order_products.create!(product: @def, quantity: gallons, price: 3)
        @dispatch.customer_orders << order
        order
      end
    end

    test 'prices the load at the farthest stop plus extra stops, split by gallons, one payable' do
      result = DispatchCalculator.new(@dispatch).apply!

      assert_equal @far, result.summary[:farthest].location
      assert_equal 530.to_d, result.summary[:total] # 6,000 gal × 0.08 (80 mi) + 1 extra stop × 50
      costs = @orders.map { |o| o.order_freight_charges.purchase.sum(:amount) }
      assert_equal [176.67, 265.0, 88.33].map(&:to_d), costs
      assert_equal 530.to_d, costs.sum

      payable = @dispatch.freight_payables.sole
      assert_equal [@fpl.id, 530.to_d], [payable.vendor_id, payable.accrued_amount]
      assert_empty FreightPayable.where(source_type: 'CustomerOrder', source_id: @orders.map(&:id))
    end

    test 'customers pay their own lane; recalculating an order keeps its share of the load' do
      DispatchCalculator.new(@dispatch).apply!
      assert_equal([200, 300, 100].map(&:to_d), @orders.map { |o| o.order_freight_charges.sale.sum(:amount) })

      Calculator.new(@orders.first.reload).apply!
      assert_equal 176.67.to_d, @orders.first.order_freight_charges.purchase.sum(:amount)
    end

    test "the dispatch's vendor is not its carrier" do
      @dispatch.update!(vendor_id: Vendor.create!(id: 'DFC-FPS', name: 'Dfc Service').id)
      assert_equal 530.to_d, DispatchCalculator.new(@dispatch).apply!.summary[:total]
      assert_equal @fpl.id, @dispatch.freight_payables.sole.vendor_id
    end

    test 'bill at least a full load charges a short load as the class full load' do
      FreightRule.find_by!(name: 'FPL load').update!(bill_full_load: true)
      # 3,000 gal on an 8,500 gal class
      @orders.flat_map(&:customer_order_products).each { |line| line.update!(quantity: 1000) }
      summary = DispatchCalculator.new(@dispatch).apply!.summary
      assert_equal 730.to_d, summary[:total] # 8,500 × 0.08 + 50
      assert_equal(730.to_d, @orders.sum { |o| o.order_freight_charges.purchase.sum(:amount) })
    end

    test 'a stop without a lane or GPS is reported' do
      FreightLane.find_by(destination_location: @far).destroy!
      result = DispatchCalculator.new(@dispatch).apply!
      assert_nil result.summary
      assert_match(/No miles for Dfc Far/, result.warnings.join)
    end

    test 'lanes paste in from Excel by name or ID' do
      text = "Origin\tDestination\tMiles\nDfc Terminal\tDfc Far\t82\n#{@terminal.id}\t#{@near.id}\t31.5"
      result = LaneImport.new(text).call
      assert_equal 2, result.imported
      assert_equal 82.to_d, FreightLane.miles(@terminal, @far)
      assert_equal 31.5.to_d, FreightLane.miles(@terminal, @near)
    end
  end
end
