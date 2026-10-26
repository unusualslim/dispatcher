# PDI IDs from the Enterprise Web Service (GetMasterData). Ship-to IDs are only unique within
# a PDI customer, so they live on the customer ↔ location link, which lets one physical
# location (e.g. the FPS warehouse pickup) serve many customers' ship-tos.
class AddPdiWebServiceIds < ActiveRecord::Migration[7.2]
  def change
    add_column :customers, :pdi_customer_id, :string
    add_index :customers, :pdi_customer_id, unique: true

    add_column :customer_locations, :pdi_location_id, :string
    add_index :customer_locations, %i[customer_id pdi_location_id], unique: true

    add_column :locations, :pdi_terminal_id, :string
    add_index :locations, :pdi_terminal_id, unique: true
  end
end
