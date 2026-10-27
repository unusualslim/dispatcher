# PDI's own key for a purchase order (WHPRCH_KEY). PO numbers are optional and not unique in PDI, so the
# PDI Purchase Orders import matches on this first.
class AddPdiPoKeyToPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :pdi_po_key, :string
    add_index :purchase_orders, :pdi_po_key, unique: true
  end
end
