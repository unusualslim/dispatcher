class AddCascadeToDispatchCustomerOrdersCustomerOrder < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :dispatch_customer_orders, :customer_orders
    add_foreign_key :dispatch_customer_orders, :customer_orders, on_delete: :cascade
  end
end
