# Admins void purchase orders instead of deleting them; posted receipts are reversed.
class AddVoidToPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :voided_at, :datetime
    add_reference :purchase_orders, :voided_by, foreign_key: { to_table: :users }
    add_column :purchase_orders, :void_reason, :text
  end
end
