class CreateCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :customer_orders do |t|
      t.date :required_delivery_date
      t.string :product
      t.references :location, null: false, foreign_key: true
      t.float :approximate_product_amount
      t.text :notes
      t.string :order_status

      t.timestamps
    end
  end
end
