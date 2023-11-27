class AddCustomerOrderIdToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_reference :dispatches, :customer_order, foreign_key: true
  end
end
