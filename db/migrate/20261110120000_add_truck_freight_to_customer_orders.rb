# The truck, driver and freight items PDI records on an order (Reports::FreightByTruck / FreightDetail).
class AddTruckFreightToCustomerOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :customer_orders, bulk: true do |t|
      t.string :pdi_vehicle_id
      t.string :pdi_vehicle
      t.string :pdi_driver
      t.decimal :pdi_gallons, precision: 14, scale: 2
      t.jsonb :pdi_freight_items, default: [], null: false
    end
    add_index :customer_orders, :pdi_vehicle_id
  end
end
