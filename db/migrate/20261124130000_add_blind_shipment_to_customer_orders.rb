# Blind shipments: our customer drop ships to their customer, so the BOL and packing list show our customer as the
# shipper (name and address typed on the order) and leave Five Points Service off.
class AddBlindShipmentToCustomerOrders < ActiveRecord::Migration[8.1]
  # Separate add_columns: strong_migrations can't check inside a bulk change_table.
  # rubocop:disable-next Rails/BulkChangeTable
  def change
    add_column :customer_orders, :blind_shipment, :boolean, default: false, null: false
    add_column :customer_orders, :blind_ship_from, :text
  end
end
