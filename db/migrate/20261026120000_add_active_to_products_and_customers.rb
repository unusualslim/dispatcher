class AddActiveToProductsAndCustomers < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :active, :boolean, default: true, null: false
    add_column :customers, :active, :boolean, default: true, null: false
  end
end
