class AddCustomerAndLocationToProductionOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :production_orders, :customer, null: true, foreign_key: true
    add_reference :production_orders, :location, null: true, foreign_key: true
  end
end
