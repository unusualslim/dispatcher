class AddLocationIdToPurchaseOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :purchase_orders, :location_id, :bigint
  end
end
