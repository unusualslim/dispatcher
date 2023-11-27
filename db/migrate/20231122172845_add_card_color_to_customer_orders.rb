class AddCardColorToCustomerOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :customer_orders, :card_color, :string
  end
end
