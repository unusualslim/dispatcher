class AddFreightOnlyToCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :customer_orders, :freight_only, :boolean
  end
end
