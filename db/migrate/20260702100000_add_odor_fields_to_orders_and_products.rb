class AddOdorFieldsToOrdersAndProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :customer_orders, :carrier, :string
    add_column :customer_orders, :invoice_date, :date
    add_column :customer_orders, :salesperson, :string

    add_column :customer_order_products, :warehouse, :string
  end
end
