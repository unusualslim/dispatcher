class AddAddressFieldsToVendors < ActiveRecord::Migration[7.0]
  def change
    add_column :vendors, :address_1, :string
    add_column :vendors, :address_2, :string
    add_column :vendors, :city, :string
    add_column :vendors, :state, :string
    add_column :vendors, :zip, :string
    add_column :vendors, :payment_terms, :string
    add_column :vendors, :payment_method, :string
  end
end
