class AddMaxStockToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :max_stock, :decimal
  end
end
