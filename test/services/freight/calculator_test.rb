require 'test_helper'

module Freight
  class CalculatorTest < ActiveSupport::TestCase
    setup do
      LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
      LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
      @terminal = Location.create!(company_name: 'Frt Terminal', location_category_id: 1, latitude: 31.9,
                                   longitude: -84.2)
      @site = Location.create!(company_name: 'Frt Site', location_category_id: 2, latitude: 32.0, longitude: -84.0)
      @carrier = Vendor.create!(id: 'FRT-KML', name: 'KML Frt')
      @class_a = FreightClass.create!(code: 'FA', full_load_quantity: 8500)
      @def = Product.create!(id: 'FRT-DEF', name: 'Frt Bulk DEF', freight_class: @class_a)
      @order = CustomerOrder.create!(location: @site, order_status: 'open_order', order_date: Date.new(2026, 10, 15),
                                     freight_origin_location: @terminal, freight_carrier_id: @carrier.id,
                                     freight_miles: 42)
      @order.customer_order_products.create!(product: @def, quantity: 9000, price: 3)
      @miles = FreightTable.create!(name: 'Frt mileage', lookup_type: 'mileage')
      @miles.rates.create!(miles_from: 0, miles_to: 50, rate: 0.05)
      @miles.rates.create!(miles_from: 50, rate: 0.08)
    end

    def rule(**attrs)
      FreightRule.create!({ name: "Rule #{FreightRule.count}", side: 'sale', charge_type: 'freight', basis: 'per_unit',
                            freight_table: @miles, effective_from: Date.new(2026, 1, 1) }.merge(attrs))
    end

    def flat(rate)
      FreightTable.create!(name: "Flat #{rate} #{FreightTable.count}", lookup_type: 'flat').tap do |t|
        t.rates.create!(rate: rate)
      end
    end

    test 'per gallon from the mileage band the order falls in' do
      rule
      charge = Calculator.new(@order).call.charges.sole
      assert_equal 'sale', charge.side
      assert_equal 450.to_d, charge.amount # 9,000 gal × 0.05 (42 mi)
    end

    test 'per load counts whole loads by the freight class' do
      rule(basis: 'per_load', freight_table: flat(600))
      charge = Calculator.new(@order).call.charges.sole
      assert_equal 2, charge.quantity # 9,000 gal on an 8,500 gal class
      assert_equal 1200.to_d, charge.amount
    end

    test 'the most specific rule wins and dates matter' do
      rule(name: 'Any')
      rule(name: 'Carrier', carrier: @carrier, freight_table: flat(0.07))
      rule(name: 'Expired', carrier: @carrier, customer: Customer.create!(name: 'Frt Cust'),
           effective_to: Date.new(2026, 1, 31))
      assert_equal 'Carrier', Calculator.new(@order).call.charges.sole.freight_rule.name
    end

    test 'accessorials: fuel surcharge on freight, extra stops, pump offs, and a markup sale over cost' do
      rule(side: 'purchase', freight_table: flat(0.04))
      rule(side: 'purchase', charge_type: 'fuel_surcharge', basis: 'percent', freight_table: flat(10))
      rule(side: 'sale', basis: 'markup', freight_table: nil, markup_percent: 25)
      rule(side: 'sale', charge_type: 'extra_stop', basis: 'per_stop', freight_table: flat(75))
      rule(side: 'sale', charge_type: 'pump_off', basis: 'per_pump_off', freight_table: flat(50), minimum_amount: 120)
      @order.update!(freight_extra_stops: 2, freight_pump_offs: 1)

      charges = Calculator.new(@order).call.charges.to_h { |c| [[c.side, c.charge_type], c.amount] }
      assert_equal 360.to_d, charges[%w[purchase freight]]          # 9,000 × 0.04
      assert_equal 36.to_d, charges[%w[purchase fuel_surcharge]]    # 10% of 360
      assert_equal 450.to_d, charges[%w[sale freight]]              # 360 × 1.25
      assert_equal 150.to_d, charges[%w[sale extra_stop]]           # 2 × 75
      assert_equal 120.to_d, charges[%w[sale pump_off]]             # 50, raised to the minimum
    end

    test 'warns when nothing has a freight class or a table has no rate' do
      @def.update!(freight_class: nil)
      assert_match(/freight class/, Calculator.new(@order).call.warnings.join)

      @def.update!(freight_class: @class_a)
      @order.update!(freight_miles: nil, freight_origin_location: nil)
      @terminal.update!(latitude: nil)
      p2p = FreightTable.create!(name: 'Frt p2p', lookup_type: 'point_to_point')
      rule(freight_table: p2p)
      assert_match(/no rate/, Calculator.new(@order).call.warnings.join)
    end

    test 'apply! replaces calculated charges, keeps manual ones, and accrues the carrier payable' do
      rule(side: 'purchase', freight_table: flat(0.04))
      @order.order_freight_charges.create!(side: 'sale', charge_type: 'freight', amount: 99, description: 'Manual')
      2.times { Calculator.new(@order).apply! }

      assert_equal 2, @order.order_freight_charges.count
      payable = @order.freight_payables.sole
      assert_equal @carrier.id, payable.vendor_id
      assert_equal 360.to_d, payable.accrued_amount
      assert_equal 'accrued', payable.status
    end

    test 'mileage rounds up to the next mileage in the table' do
      table = FreightTable.create!(name: 'Frt steps', lookup_type: 'mileage')
      { 10 => 0.04, 20 => 0.05, 30 => 0.06 }.each { |miles, rate| table.rates.create!(miles_to: miles, rate: rate) }
      assert_equal 0.04.to_d, table.rate_for(miles: 10).rate
      assert_equal 0.05.to_d, table.rate_for(miles: 11).rate
      assert_equal 0.06.to_d, table.rate_for(miles: 29.5).rate
      assert_nil table.rate_for(miles: 31)
    end

    test 'miles fall back to a GPS estimate' do
      @order.update!(freight_miles: nil)
      assert_operator @order.freight_miles_or_estimate, :>, 10
      assert @order.freight_miles_estimated?
    end
  end
end
