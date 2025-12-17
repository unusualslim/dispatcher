class AddUniqueIndexToProductionOrdersNumber < ActiveRecord::Migration[7.0]
  def change
    add_index :production_orders, :number, unique: true
  end
end
