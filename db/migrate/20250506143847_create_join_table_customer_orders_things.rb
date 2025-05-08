class CreateJoinTableCustomerOrdersThings < ActiveRecord::Migration[7.0]
  def change
    create_join_table :customer_orders, :things do |t|
      t.index :customer_order_id
      t.index :thing_id
    end
  end
end
