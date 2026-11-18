class AddReleaseNumberToCustomerOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_orders, :release_number, :string, limit: 30
  end
end
