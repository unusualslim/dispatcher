class AddCustomerToCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :customer_orders, :customer, null: true, foreign_key: true
  end
end
