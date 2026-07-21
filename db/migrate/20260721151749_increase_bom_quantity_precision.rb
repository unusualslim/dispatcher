class IncreaseBomQuantityPrecision < ActiveRecord::Migration[7.0]
  def up
    change_column :product_components, :quantity_per_unit, :decimal, precision: 12, scale: 4
  end

  def down
    change_column :product_components, :quantity_per_unit, :decimal, precision: 12, scale: 3
  end
end
