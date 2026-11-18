class AddFreightTermsToCustomerOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_orders, :freight_terms, :string
  end
end
