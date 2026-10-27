require 'test_helper'

class InventorySalesTest < ActiveSupport::TestCase
  fixtures :products, :locations, :location_categories

  setup do
    AppSetting.set(InventoryRevaluation::START_DATE_KEY, '2026-10-01')
    @location = locations(:warehouse)
    @product = products(:def_finished)
    LocationProduct.where(product: @product).delete_all
    InventoryPosting.post!(product: @product, location: @location, quantity: 100, movement_type: 'receipt',
                           unit_cost: 5)
    @order = CustomerOrder.create!(external_order_no: 'OD-1', order_status: 'billed', location: locations(:terminal),
                                   invoice_date: Date.new(2026, 10, 20))
    @line = @order.customer_order_products.create!(product_id: @product.id, product_name: @product.id, quantity: 10,
                                                   shipped_quantity: 9.5, warehouse: '2', location: @location)
  end

  def on_hand
    LocationProduct.find_by!(location: @location, product: @product).quantity.to_f
  end

  test 'a shipped PDI order takes what shipped out of stock, once' do
    2.times { InventorySales.sync!(@order) }

    assert_equal 90.5, on_hand
    sale = InventoryTransaction.find_by!(movement_type: 'sale')
    assert_equal [Date.new(2026, 10, 20), 47.5, @order], [sale.occurred_on, sale.total_cost.to_f, sale.transactable]
  end

  test 'a changed quantity reposts; a cancelled order puts the stock back' do
    InventorySales.sync!(@order)
    @line.update!(shipped_quantity: 12)
    InventorySales.sync!(@order)
    assert_equal 88.0, on_hand

    @order.update!(order_status: 'cancelled_as_order')
    InventorySales.sync!(@order)
    assert_equal 100.0, on_hand
  end

  test 'open orders, orders shipped before tracking began and dropship lines are left alone' do
    @order.update!(order_status: 'open_order')
    InventorySales.sync!(@order)
    assert_equal 100.0, on_hand

    @order.update!(order_status: 'billed', invoice_date: Date.new(2026, 9, 30))
    InventorySales.sync!(@order)
    assert_equal 100.0, on_hand

    @order.update!(invoice_date: Date.new(2026, 10, 20))
    @line.update!(warehouse: '7777')
    InventorySales.sync!(@order)
    assert_equal 100.0, on_hand
  end

  test 'nothing posts before opening balances are set' do
    AppSetting.find_by(key: InventoryRevaluation::START_DATE_KEY).destroy
    InventorySales.sync!(@order)

    assert_equal 100.0, on_hand
  end

  test 'PDI order lines read the shipped quantity' do
    xml = Nokogiri::XML(<<~XML).root
      <PDIFuelOrder><OrderNo>OD-2</OrderNo><OrderStatus>6</OrderStatus>
        <FuelDetail><OrderedProductID>101</OrderedProductID><OrderedQuantity>2500</OrderedQuantity>
          <LoadDetail><OriginSiteID>2</OriginSiteID><LiftNetQuantity>1200.5</LiftNetQuantity></LoadDetail>
          <LoadDetail><OriginSiteID>2</OriginSiteID><LiftNetQuantity>1290</LiftNetQuantity></LoadDetail>
        </FuelDetail>
        <WarehouseDetail><WarehouseProductID>BF1</WarehouseProductID><OrderedQuantity>10</OrderedQuantity>
          <PickedQuantity>8</PickedQuantity><InvoicedQuantity>0</InvoicedQuantity></WarehouseDetail>
      </PDIFuelOrder>
    XML
    fuel, warehouse = PdiOrders::OrderNode.new(xml).lines

    assert_equal BigDecimal('2490.5'), fuel.shipped_quantity
    assert_equal 8, warehouse.shipped_quantity
  end
end
