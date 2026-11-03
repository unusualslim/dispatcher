# rubocop:disable Metrics/MethodLength -- table definitions read best whole
# Expense POs: parts and supplies that never pass through inventory (e.g. packaging equipment parts).
# They are tracked in the app only; AP keys the vendor bill into PDI against each line's GL account.
class AddExpensePurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :po_type, :string, null: false, default: 'inventory'
    add_index :purchase_orders, :po_type

    create_table :expense_accounts do |t|
      t.string :account, null: false # Major-Sub, e.g. 6150-01; the site segment comes from each line's site
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
    end
    add_index :expense_accounts, :account, unique: true

    add_column :purchase_order_line_items, :vendor_part_number, :string
    add_reference :purchase_order_line_items, :expense_account, foreign_key: true
    add_reference :purchase_order_line_items, :equipment, foreign_key: { to_table: :things }
    add_reference :purchase_order_line_items, :location, foreign_key: true # the site the expense belongs to

    # Equipment (packaging lines, fillers...) lives with trucks and trailers on Equipment & Assets.
    add_reference :things, :location, foreign_key: true
  end
end
# rubocop:enable Metrics/MethodLength
