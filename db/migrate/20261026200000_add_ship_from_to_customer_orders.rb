# The warehouse an order entered in the app ships from (PDI orders carry it per line); MRP plans it there.
# Open app-entered orders start at Five Points Service (PDI site 0002).
class AddShipFromToCustomerOrders < ActiveRecord::Migration[7.2]
  OPEN_STATUSES = ['Open Order', 'Quote', 'Pending', 'Released for Dispatch', 'Dispatched', 'Released for Picking',
                   'Picking in Progress', 'Released for Billing', 'Staged', 'Loaded'].freeze

  def up
    add_reference :customer_orders, :ship_from_location, foreign_key: { to_table: :locations }, index: true
    statuses = OPEN_STATUSES.map { |s| connection.quote(s) }.join(', ')
    execute <<~SQL.squish
      UPDATE customer_orders SET ship_from_location_id = (SELECT id FROM locations WHERE pdi_site_code = '0002' LIMIT 1)
      WHERE external_order_no IS NULL AND order_status IN (#{statuses})
    SQL
  end

  def down
    remove_reference :customer_orders, :ship_from_location, foreign_key: { to_table: :locations }, index: true
  end
end
