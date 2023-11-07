class CreateDispatchCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :dispatch_customer_orders do |t|
      t.references :dispatch, null: false, foreign_key: true
      t.references :customer_order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
