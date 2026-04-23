class DropDispatchCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    drop_table :dispatch_customer_orders, if_exists: true
  end
end
