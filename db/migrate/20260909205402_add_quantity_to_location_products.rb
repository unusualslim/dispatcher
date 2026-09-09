class AddQuantityToLocationProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :location_products, :quantity, :decimal, precision: 14, scale: 3, default: 0.0, null: false
  end
end
