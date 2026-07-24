class AddOtherChargesToPurchaseOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :purchase_orders, :other_charges, :decimal, precision: 10, scale: 2
    add_column :purchase_orders, :other_charges_description, :string
  end
end
