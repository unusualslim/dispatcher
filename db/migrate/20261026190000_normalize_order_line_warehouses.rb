# An earlier order import stored line warehouses as "2 - FPS-Main" / "7777 - Dropship - Third Party WH".
# Keep just PDI's site ID (as the API order sync does) and link the warehouse with that pdi_site_code.
class NormalizeOrderLineWarehouses < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE customer_order_products SET warehouse = substring(warehouse from '^\\s*(\\d+)\\s*-')
      WHERE warehouse ~ '^\\s*\\d+\\s*-'
    SQL
    execute <<~SQL.squish
      UPDATE customer_order_products l SET location_id = loc.id
      FROM locations loc
      WHERE l.location_id IS NULL AND l.warehouse ~ '^\\d+$' AND loc.pdi_site_code = lpad(l.warehouse, 4, '0')
    SQL
  end

  def down
    # Data cleanup; the original text isn't needed.
  end
end
