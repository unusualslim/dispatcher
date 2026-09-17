class AddPdiSiteCodeToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :pdi_site_code, :string
  end
end
