require 'test_helper'

class FinancialDashboardTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories

  setup do
    @fuel = products(:def_concentrate).tap { |p| p.update!(category: 'Diesel') }
    ReportingGroup.find_by!(name: 'Diesel').update!(item_type: 'fuel')
    @case = products(:def_finished).tap { |p| p.update!(category: 'Packaged') }
  end

  def order(invoice_date, order_date: invoice_date - 2, required: invoice_date, status: 'billed', lines: [])
    CustomerOrder.create!(location: locations(:terminal), order_status: status, invoice_date: invoice_date,
                          order_date: order_date, required_delivery_date: required).tap do |o|
      lines.each { |attrs| o.customer_order_products.create!(attrs) }
    end
  end

  test 'compares the same days of the prior month and of last year' do
    d = FinancialDashboard.new(month: Date.new(2026, 10, 1), today: Date.new(2026, 10, 27))

    assert_equal [Date.new(2026, 10, 1)..Date.new(2026, 10, 27), Date.new(2026, 9, 1)..Date.new(2026, 9, 27),
                  Date.new(2025, 10, 1)..Date.new(2025, 10, 27)], d.ranges.values
    assert_predicate d, :month_to_date?
    march = FinancialDashboard.new(month: Date.new(2026, 3, 1), today: Date.new(2026, 10, 27)).ranges
    assert_equal Date.new(2026, 2, 28), march[:prior_month].end, 'a full month compares with all of the shorter one'
  end

  test 'sales split by item type with taxes taken out of tax-inclusive prices' do
    order(Date.new(2026, 10, 5), lines: [
            { product_id: @fuel.id, quantity: 1000, shipped_quantity: 990, price: 3, tax_per_unit: 0.5,
              price_includes_taxes: true },
            { product_id: @case.id, quantity: 10, price: 20 }
          ])
    order(Date.new(2026, 10, 6), status: 'cancelled_as_order',
                                 lines: [{ product_id: @case.id, quantity: 5, price: 20 }])
    order(Date.new(2026, 11, 1), lines: [{ product_id: @case.id, quantity: 5, price: 20 }])
    sales = FinancialDashboard::Sales.new(Date.new(2026, 10, 1)..Date.new(2026, 10, 31))

    assert_equal 2475.0, sales.by_type['fuel'][0].to_f, '990 × (3 − 0.5)'
    assert_equal [200.0, 495.0, 3170.0, 990.0, 1], [sales.by_type['warehouse'][0].to_f, sales.taxes.to_f,
                                                    sales.total.to_f, sales.gallons.to_f, sales.order_count]
  end

  test 'delivery time and on-time share run from order date to invoice date' do
    order(Date.new(2026, 10, 10), order_date: Date.new(2026, 10, 7), required: Date.new(2026, 10, 9))
    order(Date.new(2026, 10, 12), order_date: Date.new(2026, 10, 11), required: Date.new(2026, 10, 12))
    ops = FinancialDashboard::Operations.new(Date.new(2026, 10, 1)..Date.new(2026, 10, 31))

    assert_equal [2.0, 0.5], [ops.average_delivery_days.to_f, ops.on_time_share.to_f]
  end
end
