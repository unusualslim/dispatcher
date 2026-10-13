class AddStandardCostToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :standard_cost, :decimal, precision: 12, scale: 4
  end
end
