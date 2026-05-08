class AddPdiPackageCodeToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :pdi_package_code, :string
  end
end
