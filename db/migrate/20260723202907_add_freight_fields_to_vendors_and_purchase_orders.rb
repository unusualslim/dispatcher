class AddFreightFieldsToVendorsAndPurchaseOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :vendors, :freight_terms, :string
    add_column :purchase_orders, :freight_terms, :string
    add_column :purchase_orders, :freight_amount, :decimal, precision: 10, scale: 2
  end
end
