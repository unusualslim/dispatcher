# Per-warehouse MRP: the warehouse each order line ships from (PDI's site on the line, linked to the
# location with that pdi_site_code; `warehouse` keeps PDI's raw site ID, e.g. 7777 = dropship), and
# production orders linked to their warehouse by the name they were entered with.
class AddWarehouseToOrderLines < ActiveRecord::Migration[7.2]
  PRODUCTION_SITES = { 'FPS-Main' => '0002', 'Five Points Service' => '0002',
                       'FPS-South' => '0110', 'Five Points South' => '0110' }.freeze

  def up
    add_reference :customer_order_products, :location, foreign_key: true, index: true
    PRODUCTION_SITES.each do |name, site|
      execute <<~SQL.squish
        UPDATE production_orders SET location_id = (SELECT id FROM locations WHERE pdi_site_code = #{quote(site)} LIMIT 1)
        WHERE location_id IS NULL AND location_name = #{quote(name)}
      SQL
    end
  end

  def down
    remove_reference :customer_order_products, :location, foreign_key: true, index: true
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
