class AddPdiVendorIdToVendors < ActiveRecord::Migration[7.0]
  def change
    add_column :vendors, :pdi_vendor_id, :string
  end
end
