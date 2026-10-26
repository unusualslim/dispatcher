require 'test_helper'

# Per-warehouse MRP needs each PDI order line's warehouse.
class PdiOrderWarehouseTest < ActiveSupport::TestCase
  def feed
    file_fixture('pdi_orders.xml').read
  end

  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'order lines keep the PDI warehouse site they ship from, linked to that warehouse' do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    main = Location.create!(company_name: 'FPS Main (test)', location_category_id: 1, pdi_site_code: '0777')
    PdiOrderApiImportService.call(feed.sub('<WarehouseSiteID>7777</WarehouseSiteID>',
                                           '<WarehouseSiteID>777</WarehouseSiteID>'))

    line = CustomerOrder.find_by!(external_order_no: 'OD-050103-26').customer_order_products.sole
    assert_equal ['777', main], [line.warehouse, line.location]

    PdiOrderApiImportService.call(feed)
    line = CustomerOrder.find_by!(external_order_no: 'OD-050103-26').customer_order_products.sole
    assert_equal ['7777', nil, true], [line.warehouse, line.location, line.dropship?], 'dropship: no warehouse of ours'
  end

  test 'fuel lines not yet on a load plan at the main warehouse until PDI sets their origin' do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    main = Location.find_by(pdi_site_code: '0002') ||
           Location.create!(company_name: 'FPS Main (test)', location_category_id: 1, pdi_site_code: '0002')

    PdiOrderApiImportService.call(feed)
    fuel_lines = CustomerOrder.find_by!(external_order_no: 'OD-051313-26').customer_order_products
                              .where.not(product_name: 'FRT')

    assert(fuel_lines.all? { |line| line.location == main && line.warehouse.nil? })
  end
end
