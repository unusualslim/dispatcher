class AddProductFkToProductionOrderComponents < ActiveRecord::Migration[7.0]
  def change
    add_reference :production_order_components, :product, foreign_key: true
    add_column :production_order_components, :quantity_actual, :decimal, precision: 12, scale: 3
  end
end
