class AddProductionDateToProductionOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :production_orders, :production_date, :date
  end
end
