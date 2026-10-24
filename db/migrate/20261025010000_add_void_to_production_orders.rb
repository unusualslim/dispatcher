# Admins void production orders instead of deleting them; the record and its history stay.
class AddVoidToProductionOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :production_orders, :voided_at, :datetime
    add_reference :production_orders, :voided_by, foreign_key: { to_table: :users }
    add_column :production_orders, :void_reason, :text
  end
end
