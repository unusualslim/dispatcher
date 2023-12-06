class RemoveCustomerOrderIdFromDispatches < ActiveRecord::Migration[7.0]
  def change
    remove_column :dispatches, :customer_order_id
  end
end
