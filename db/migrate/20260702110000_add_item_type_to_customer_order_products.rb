class AddItemTypeToCustomerOrderProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :customer_order_products, :item_type, :string, default: 'buy', null: false
  end
end
