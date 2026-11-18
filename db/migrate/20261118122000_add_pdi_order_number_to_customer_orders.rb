# The PDI order number Send to PDI gave the order (OD-09xxxx-YY), kept even while PDI has only queued it.
class AddPdiOrderNumberToCustomerOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :customer_orders, :pdi_order_number, :string, limit: 15
    add_index :customer_orders, :pdi_order_number, unique: true, algorithm: :concurrently
  end
end
