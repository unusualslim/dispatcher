class AddCompanyNameToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :company_name, :string
  end
end
