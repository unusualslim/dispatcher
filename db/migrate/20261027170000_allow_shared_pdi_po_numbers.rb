# PDI PO numbers are free text and repeat ("TODD", "PBOC031226BULK1"); POs from PDI are identified by
# pdi_po_key, so the number no longer has to be unique.
class AllowSharedPdiPoNumbers < ActiveRecord::Migration[7.2]
  def change
    remove_index :purchase_orders, :pdi_reference, unique: true
    add_index :purchase_orders, :pdi_reference
  end
end
