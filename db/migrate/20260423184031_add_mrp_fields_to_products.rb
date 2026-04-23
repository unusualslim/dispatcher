class AddMrpFieldsToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :is_raw_material, :boolean, default: false, null: false
    add_column :products, :current_stock, :decimal, precision: 14, scale: 3, default: 0
    add_column :products, :reorder_point, :decimal, precision: 14, scale: 3
    add_column :products, :safety_stock, :decimal, precision: 14, scale: 3, default: 0
    add_column :products, :cost_per_unit, :decimal, precision: 12, scale: 4
  end
end
