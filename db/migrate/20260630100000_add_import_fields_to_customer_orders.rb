class AddImportFieldsToCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :customer_orders, :external_order_no, :string
    add_column :customer_orders, :order_date, :datetime
    add_column :customer_orders, :invoice_no, :string
    add_column :customer_orders, :odor_status, :string

    add_index :customer_orders, :external_order_no
  end
end
