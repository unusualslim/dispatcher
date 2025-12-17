class AddProductToProductionOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :production_orders, :product, null: true, foreign_key: true
  end
end
